#!/usr/bin/env bash
# Prefetch / re-enable sky130 PDK with a long httpx timeout.
# ciel's default client timeout (~5s) causes ReadTimeout on cold GH runners.
set -euo pipefail

: "${PDK_ROOT:?PDK_ROOT required}"
: "${CIEL_PDK_FAMILY:?CIEL_PDK_FAMILY required}"
: "${CIEL_PDK_VERSION:?CIEL_PDK_VERSION required}"

python3 -m pip install --user 'ciel==2.6.1' 'httpx' 'rich' 'zstandard'
export PATH="${HOME}/.local/bin:${PATH}"

python3 <<'PY'
import httpx
import ciel.github
from ciel.manage import enable
from ciel.source import StaticWebDataSource
from rich.console import Console
import os

_orig = ciel.github.GitHubSession.__init__


def _init(self, *args, **kwargs):
    kwargs.setdefault(
        "timeout",
        httpx.Timeout(1800.0, connect=120.0, pool=120.0),
    )
    return _orig(self, *args, **kwargs)


ciel.github.GitHubSession.__init__ = _init

pdk_root = os.environ["PDK_ROOT"]
family = os.environ["CIEL_PDK_FAMILY"]
version = os.environ["CIEL_PDK_VERSION"]
ds = StaticWebDataSource("https://fossi-foundation.github.io/ciel-releases")
console = Console()
last = None
for attempt in range(1, 4):
    try:
        console.print(f"[bold]ciel enable attempt {attempt}/3[/bold]")
        enable(pdk_root, family, version, data_source=ds, output=console)
        console.print("[green]PDK ready[/green]")
        raise SystemExit(0)
    except SystemExit:
        raise
    except Exception as e:
        last = e
        console.print(f"[red]attempt {attempt} failed: {e}[/red]")
raise SystemExit(f"PDK prefetch failed: {last}")
PY
