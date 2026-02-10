#!/usr/bin/env bash
# Set up the gclient workspace needed for full SDK builds.
#
# The Dart DEPS file hardcodes "dart_root": "sdk", so the checkout must be
# in a directory called `sdk/` under the `.gclient` file. This script creates
# that structure using a symlink if the checkout isn't already named `sdk/`.
#
# See docs/Building.md for full details.
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Check depot_tools
if ! command -v gclient &>/dev/null; then
  fail "depot_tools not found in PATH. Run the setup-dart-sdk-dev skill first."
  exit 1
fi
ok "depot_tools found: $(which gclient)"

# Check if we're already in a gclient workspace
PARENT_DIR="$(dirname "$SDK_ROOT")"
CHECKOUT_NAME="$(basename "$SDK_ROOT")"

if [ -f "$PARENT_DIR/.gclient" ]; then
  ok ".gclient file already exists at $PARENT_DIR/.gclient"
elif [ "$CHECKOUT_NAME" = "sdk" ]; then
  # Checkout is already named 'sdk', create .gclient in parent
  echo "Creating .gclient in $PARENT_DIR..."
  cat > "$PARENT_DIR/.gclient" <<'GCLIENT_EOF'
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
  ok "Created .gclient at $PARENT_DIR/.gclient"
else
  # Checkout is not named 'sdk' — create a wrapper directory with a symlink
  WORKSPACE="$PARENT_DIR/dart-sdk-workspace"
  if [ -d "$WORKSPACE" ] && [ -L "$WORKSPACE/sdk" ]; then
    ok "Workspace already exists at $WORKSPACE"
    PARENT_DIR="$WORKSPACE"
  else
    echo "Checkout is named '$CHECKOUT_NAME', not 'sdk'."
    echo "Creating workspace at $WORKSPACE with symlink..."
    mkdir -p "$WORKSPACE"
    ln -sf "$SDK_ROOT" "$WORKSPACE/sdk"
    cat > "$WORKSPACE/.gclient" <<'GCLIENT_EOF'
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
    ok "Created workspace at $WORKSPACE"
    ok "Symlinked $WORKSPACE/sdk -> $SDK_ROOT"
    PARENT_DIR="$WORKSPACE"
  fi
fi

echo ""
echo "Running gclient sync from $PARENT_DIR..."
echo "This will download all dependencies (C++ libs, tools, etc.)."
echo "This may take a while on first run."
echo ""

cd "$PARENT_DIR"
gclient sync -D

echo ""
ok "gclient sync complete!"
echo ""
echo "You can now build the SDK:"
echo "  cd $SDK_ROOT"
echo "  ./tools/build.py --mode release create_sdk"
echo ""
echo "See docs/Building.md for more build options."
