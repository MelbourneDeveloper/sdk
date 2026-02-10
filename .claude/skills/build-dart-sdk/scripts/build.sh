#!/usr/bin/env bash
# Build the Dart SDK.
#
# Usage:
#   bash build.sh                    — build 'most' target in release mode
#   bash build.sh runtime            — build VM runtime only (fastest)
#   bash build.sh create_sdk         — build full SDK
#   bash build.sh --mode debug most  — build in debug mode
#   bash build.sh sync              — set up gclient workspace + sync deps
#
# Environment variables:
#   BUILD_MODE    — override default mode (release)
#   BUILD_ARCH    — override auto-detected architecture
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
DEPOT_TOOLS_DIR="${DEPOT_TOOLS_DIR:-$HOME/depot_tools}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

detect_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    arm64|aarch64) echo "arm64" ;;
    x86_64|amd64)  echo "x64" ;;
    *)             echo "x64" ;;
  esac
}

detect_build_dir() {
  local mode="$1"
  local arch="$2"
  local mode_cap arch_cap

  # Capitalize mode
  case "$mode" in
    release) mode_cap="Release" ;;
    debug)   mode_cap="Debug" ;;
    *)       mode_cap="Release" ;;
  esac

  # Capitalize arch
  case "$arch" in
    arm64)  arch_cap="ARM64" ;;
    x64)    arch_cap="X64" ;;
    *)      arch_cap="X64" ;;
  esac

  if [[ "$(uname)" == "Darwin" ]]; then
    echo "$SDK_ROOT/xcodebuild/${mode_cap}${arch_cap}"
  else
    echo "$SDK_ROOT/out/${mode_cap}${arch_cap}"
  fi
}

ensure_depot_tools() {
  if command -v gclient &>/dev/null; then
    return 0
  elif [ -d "$DEPOT_TOOLS_DIR" ] && [ -f "$DEPOT_TOOLS_DIR/gclient" ]; then
    export PATH="$DEPOT_TOOLS_DIR:$PATH"
    return 0
  else
    fail "depot_tools not found. Run the setup-dart-sdk-dev skill first."
    exit 1
  fi
}

# ---- gclient sync ----
do_sync() {
  ensure_depot_tools
  ok "depot_tools found: $(which gclient)"

  local parent_dir checkout_name workspace_dir
  parent_dir="$(dirname "$SDK_ROOT")"
  checkout_name="$(basename "$SDK_ROOT")"

  if [ -f "$parent_dir/.gclient" ]; then
    ok ".gclient already exists at $parent_dir"
    workspace_dir="$parent_dir"
  elif [ "$checkout_name" = "sdk" ]; then
    echo "Creating .gclient in $parent_dir..."
    cat > "$parent_dir/.gclient" <<'GCLIENT_EOF'
solutions = [
  {
    "name": "sdk",
    "url": "https://dart.googlesource.com/sdk.git",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
  },
]
GCLIENT_EOF
    ok "Created .gclient at $parent_dir"
    workspace_dir="$parent_dir"
  else
    workspace_dir="$parent_dir/dart-sdk-workspace"
    if [ -d "$workspace_dir" ] && [ -L "$workspace_dir/sdk" ]; then
      ok "Workspace already exists at $workspace_dir"
    else
      echo "Checkout is '$checkout_name', not 'sdk'. Creating workspace with symlink..."
      mkdir -p "$workspace_dir"
      ln -sf "$SDK_ROOT" "$workspace_dir/sdk"
      cat > "$workspace_dir/.gclient" <<'GCLIENT_EOF'
solutions = [
  {
    "name": "sdk",
    "url": "https://dart.googlesource.com/sdk.git",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
  },
]
GCLIENT_EOF
      ok "Created workspace at $workspace_dir (sdk -> $SDK_ROOT)"
    fi
  fi

  echo ""
  echo "Running gclient sync (first run may take 10-30 minutes)..."
  cd "$workspace_dir"
  gclient sync -D

  echo ""
  ok "gclient sync complete!"
}

# ---- Build ----
do_build() {
  local mode="${BUILD_MODE:-release}"
  local arch="${BUILD_ARCH:-$(detect_arch)}"
  local targets=()

  # Parse arguments
  while [ $# -gt 0 ]; do
    case "$1" in
      --mode|-m)
        mode="$2"
        shift 2
        ;;
      --arch|-a)
        arch="$2"
        shift 2
        ;;
      *)
        targets+=("$1")
        shift
        ;;
    esac
  done

  # Default target
  if [ ${#targets[@]} -eq 0 ]; then
    targets=("most")
  fi

  local build_dir
  build_dir=$(detect_build_dir "$mode" "$arch")

  echo "=== Building Dart SDK ==="
  echo "  Mode:    $mode"
  echo "  Arch:    $arch"
  echo "  Targets: ${targets[*]}"
  echo "  Output:  $build_dir"
  echo ""

  if [ ! -f "$SDK_ROOT/tools/build.py" ]; then
    fail "tools/build.py not found. Are you in the SDK root?"
    exit 1
  fi

  python3 "$SDK_ROOT/tools/build.py" --mode "$mode" --arch "$arch" "${targets[@]}"

  echo ""
  ok "Build complete! Output: $build_dir"
}

# ---- Main ----
case "${1:-}" in
  sync)
    do_sync
    ;;
  "")
    do_build
    ;;
  *)
    do_build "$@"
    ;;
esac
