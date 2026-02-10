#!/usr/bin/env bash
# Run Dart SDK tests.
#
# Usage:
#   bash test.sh language                          — run VM language tests
#   bash test.sh language/record_spreads           — run specific test dir
#   bash test.sh corelib/ListTest                  — run single test
#   bash test.sh --compiler dart2analyzer language  — analyzer tests
#   bash test.sh --compiler dart2js --runtime chrome language
#
# Environment variables:
#   TEST_MODE     — override mode (default: release)
#   TEST_TASKS    — parallel tasks (default: auto)
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Defaults
mode="${TEST_MODE:-release}"
compiler=""
runtime=""
tasks="${TEST_TASKS:-}"
selectors=()
extra_args=()

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --mode|-m)
      mode="$2"; shift 2 ;;
    --compiler|-c)
      compiler="$2"; shift 2 ;;
    --runtime|-r)
      runtime="$2"; shift 2 ;;
    --tasks)
      tasks="$2"; shift 2 ;;
    --*)
      extra_args+=("$1" "$2"); shift 2 ;;
    *)
      selectors+=("$1"); shift ;;
  esac
done

if [ ${#selectors[@]} -eq 0 ]; then
  fail "Usage: bash test.sh [options] <selector>"
  echo ""
  echo "  Selectors: language, corelib, lib, standalone, web, ffi"
  echo "  Options:   --compiler (dartk|dart2js|dart2analyzer|ddc)"
  echo "             --runtime (vm|d8|chrome|firefox|none)"
  echo "             --mode (debug|release)"
  echo "             --tasks N"
  echo ""
  echo "  Examples:"
  echo "    bash test.sh language"
  echo "    bash test.sh language/record_spreads"
  echo "    bash test.sh --compiler dart2analyzer language"
  exit 1
fi

# Build test.py command
cmd=(python3 "$SDK_ROOT/tools/test.py" "-m$mode" --progress color --time)

if [ -n "$compiler" ]; then
  cmd+=(--compiler="$compiler")
fi

if [ -n "$runtime" ]; then
  cmd+=(--runtime="$runtime")
elif [ -z "$compiler" ]; then
  # Default runtime for VM tests
  cmd+=(--runtime=vm)
fi

if [ -n "$tasks" ]; then
  cmd+=(--tasks "$tasks")
fi

cmd+=("${extra_args[@]}" "${selectors[@]}")

echo "=== Running Dart SDK Tests ==="
echo "  Mode:     $mode"
[ -n "$compiler" ] && echo "  Compiler: $compiler"
[ -n "$runtime" ]  && echo "  Runtime:  $runtime"
echo "  Selector: ${selectors[*]}"
echo ""
echo "  Command: ${cmd[*]}"
echo ""

# Check test.py exists
if [ ! -f "$SDK_ROOT/tools/test.py" ]; then
  fail "tools/test.py not found"
  exit 1
fi

# Check for a built SDK
detect_build_dir() {
  local arch arch_cap
  arch=$(uname -m)
  case "$arch" in
    arm64|aarch64) arch_cap="ARM64" ;;
    *)             arch_cap="X64" ;;
  esac
  local mode_cap
  case "$mode" in
    release) mode_cap="Release" ;;
    *)       mode_cap="Debug" ;;
  esac
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "$SDK_ROOT/xcodebuild/${mode_cap}${arch_cap}"
  else
    echo "$SDK_ROOT/out/${mode_cap}${arch_cap}"
  fi
}

build_dir=$(detect_build_dir)
if [ ! -d "$build_dir" ]; then
  warn "No build found at $build_dir"
  warn "Run: bash .claude/skills/build-dart-sdk/scripts/build.sh"
  echo ""
fi

"${cmd[@]}"
