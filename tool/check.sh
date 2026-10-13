#!/usr/bin/env bash
# 모든 검사 (Linux/CI). 내용은 tool/check.dart 에 있다.
set -euo pipefail
cd "$(dirname "$0")/.."
exec dart run tool/check.dart "$@"
