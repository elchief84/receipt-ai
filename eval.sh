#!/usr/bin/env bash
# Rigenera il report delle metriche OCR/layout dal corpus locale debug/
# e lo apre. Uso:  ./eval.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/mobile"

flutter test test/eval_corpus_test.dart

REPORT="$ROOT/docs/OCR_EVAL.md"
echo
echo "================================================================"
echo " Report: $REPORT"
echo "================================================================"
cat "$REPORT"

case "$(uname)" in
  Darwin) open "$REPORT" ;;
esac
