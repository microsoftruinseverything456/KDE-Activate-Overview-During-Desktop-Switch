#!/bin/bash
# Build dist/overview-during-desktop-switch.kwinscript, the file System Settings
# and the KDE Store install from (a zip of package/).
#   tools/package.sh [OUTDIR]
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT="${1:-$ROOT/dist}"
mkdir -p "$OUT"
python3 - "$ROOT/package" "$OUT" <<'PY'
import os, sys, zipfile
package, out = sys.argv[1], sys.argv[2]
path = os.path.abspath(os.path.join(out, "overview-during-desktop-switch.kwinscript"))
with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(package):
        for name in sorted(files):
            full = os.path.join(root, name)
            z.write(full, os.path.relpath(full, package))
print(path)
PY
