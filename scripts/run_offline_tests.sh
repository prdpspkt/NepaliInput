#!/usr/bin/env bash
# Compiles and runs the offline transliteration tests.
#   ./scripts/run_offline_tests.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/build/offline_engine_tests"

mkdir -p "$ROOT/build"
swiftc -O \
    "$ROOT/Sources/OfflineTransliterationEngine.swift" \
    "$ROOT/Tests/main.swift" \
    -o "$BIN"

"$BIN" "$ROOT/Resources/lexicon/ne_seed_lexicon.tsv"
