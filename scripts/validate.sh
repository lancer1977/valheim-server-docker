#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== valheim-logfilter"
(cd "${repo_root}/valheim-logfilter" && go test ./...)

echo "== env2cfg"
PYTHONPATH="${repo_root}/env2cfg${PYTHONPATH:+:${PYTHONPATH}}" python3 - <<'PY'
import importlib.util
from pathlib import Path

path = Path("env2cfg/test/test_env2cfg.py")
spec = importlib.util.spec_from_file_location("test_env2cfg", path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

for name in sorted(item for item in dir(module) if item.startswith("test_")):
    test = getattr(module, name)
    if callable(test):
        print(name)
        test()
PY
