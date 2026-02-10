#!/usr/bin/env bash
# Setup script for Dart SDK development environment.
# Usage:
#   bash setup.sh check   — diagnose what's missing
#   bash setup.sh setup   — install depot_tools + bootstrapping SDK
#   bash setup.sh gclient — set up gclient workspace + sync deps
#   bash setup.sh build   — build the SDK (release mode)
#   bash setup.sh test <suite> — run tests via test.py

set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
DEPOT_TOOLS_DIR="${DEPOT_TOOLS_DIR:-$HOME/depot_tools}"
BOOTSTRAP_DART="$SDK_ROOT/tools/sdks/dart-sdk/bin/dart"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# ---- Check functions ----

check_depot_tools() {
  if command -v gclient &>/dev/null; then
    ok "depot_tools found: $(which gclient)"
    return 0
  elif [ -d "$DEPOT_TOOLS_DIR" ] && [ -f "$DEPOT_TOOLS_DIR/gclient" ]; then
    warn "depot_tools exists at $DEPOT_TOOLS_DIR but not in PATH"
    return 1
  else
    fail "depot_tools not found"
    return 1
  fi
}

check_bootstrap_sdk() {
  if [ -x "$BOOTSTRAP_DART" ]; then
    local version
    version=$("$BOOTSTRAP_DART" --version 2>&1)
    ok "Bootstrapping SDK: $version"
    return 0
  else
    fail "Bootstrapping SDK not found at tools/sdks/dart-sdk/bin/dart"
    return 1
  fi
}

check_package_config() {
  if [ -f "$SDK_ROOT/.dart_tool/package_config.json" ]; then
    ok "package_config.json exists"
    return 0
  else
    fail "package_config.json missing — run fetch_deps.sh"
    return 1
  fi
}

check_third_party() {
  local missing=0
  for pkg in core tools test dart_style http; do
    if [ ! -d "$SDK_ROOT/third_party/pkg/$pkg" ]; then
      ((missing++)) || true
    fi
  done
  if [ "$missing" -eq 0 ]; then
    ok "third_party/pkg/ dependencies present"
    return 0
  else
    fail "$missing key third_party/pkg/ packages missing — run fetch_deps.sh"
    return 1
  fi
}

check_xcode_tools() {
  if [[ "$(uname)" == "Darwin" ]]; then
    if xcode-select -p &>/dev/null; then
      ok "Xcode command-line tools installed"
      return 0
    else
      fail "Xcode command-line tools not installed"
      return 1
    fi
  fi
  return 0
}

check_gclient_workspace() {
  local parent_dir
  parent_dir="$(dirname "$SDK_ROOT")"
  local workspace_dir="$parent_dir/dart-sdk-workspace"

  if [ -f "$parent_dir/.gclient" ]; then
    ok "gclient workspace: $parent_dir"
    return 0
  elif [ -f "$workspace_dir/.gclient" ]; then
    ok "gclient workspace: $workspace_dir"
    return 0
  else
    warn "No gclient workspace — run 'setup.sh gclient' for full builds"
    return 1
  fi
}

check_sdk_build() {
  # Check for a built SDK (release mode, auto-detect arch)
  local arch
  arch=$(uname -m)
  case "$arch" in
    arm64|aarch64) arch="ARM64" ;;
    x86_64|amd64) arch="X64" ;;
    *) arch="X64" ;;
  esac

  local build_dir
  if [[ "$(uname)" == "Darwin" ]]; then
    build_dir="$SDK_ROOT/xcodebuild/Release${arch}"
  else
    build_dir="$SDK_ROOT/out/Release${arch}"
  fi

  if [ -x "$build_dir/dart-sdk/bin/dart" ]; then
    ok "Built SDK found at $build_dir"
    return 0
  else
    warn "No built SDK — run 'setup.sh build' for full builds"
    return 1
  fi
}

check_system_dart() {
  if command -v dart &>/dev/null; then
    local version
    version=$(dart --version 2>&1)
    echo -e "    System Dart: $version"
  else
    echo -e "    System Dart: not found"
  fi
}

do_check() {
  echo "=== Dart SDK Dev Environment Check ==="
  echo ""
  echo "SDK root: $SDK_ROOT"
  check_system_dart
  echo ""

  local issues=0
  check_xcode_tools       || ((issues++)) || true
  check_depot_tools       || ((issues++)) || true
  check_bootstrap_sdk     || ((issues++)) || true
  check_third_party       || ((issues++)) || true
  check_package_config    || ((issues++)) || true
  check_gclient_workspace || ((issues++)) || true
  check_sdk_build         || ((issues++)) || true

  echo ""
  if [ "$issues" -eq 0 ]; then
    ok "Everything looks good!"
  else
    warn "$issues issue(s) found."
  fi
}

# ---- Setup functions ----

install_depot_tools() {
  if [ -d "$DEPOT_TOOLS_DIR" ] && [ -f "$DEPOT_TOOLS_DIR/cipd" ]; then
    ok "depot_tools already exists at $DEPOT_TOOLS_DIR"
  else
    echo "Cloning depot_tools to $DEPOT_TOOLS_DIR..."
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
  fi

  export PATH="$DEPOT_TOOLS_DIR:$PATH"

  local shell_profile=""
  if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    shell_profile="$HOME/.zshrc"
  elif [ -f "$HOME/.bash_profile" ]; then
    shell_profile="$HOME/.bash_profile"
  else
    shell_profile="$HOME/.bashrc"
  fi

  if ! grep -q "depot_tools" "$shell_profile" 2>/dev/null; then
    echo "" >> "$shell_profile"
    echo "# depot_tools for Dart SDK development" >> "$shell_profile"
    echo "export PATH=\"$DEPOT_TOOLS_DIR:\$PATH\"" >> "$shell_profile"
    ok "Added depot_tools to $shell_profile"
    warn "Run 'source $shell_profile' or open a new terminal for PATH changes"
  else
    ok "depot_tools PATH already in $shell_profile"
  fi
}

install_bootstrap_sdk() {
  if [ -x "$BOOTSTRAP_DART" ]; then
    ok "Bootstrapping SDK already installed"
    return 0
  fi

  local sdk_tag
  sdk_tag=$(grep '"sdk_tag"' "$SDK_ROOT/DEPS" | sed 's/.*"git_revision:\([^"]*\)".*/\1/')
  if [ -z "$sdk_tag" ]; then
    fail "Could not parse sdk_tag from DEPS"
    return 1
  fi

  echo "Downloading bootstrapping SDK (revision: ${sdk_tag:0:12}...)..."
  local cipd="$DEPOT_TOOLS_DIR/cipd"
  if [ ! -x "$cipd" ]; then
    fail "cipd not found at $cipd"
    return 1
  fi

  "$cipd" ensure \
    -root "$SDK_ROOT/tools/sdks/dart-sdk" \
    -ensure-file - <<CIPD_EOF
dart/dart-sdk/\${platform} git_revision:$sdk_tag
CIPD_EOF

  if [ -x "$BOOTSTRAP_DART" ]; then
    local version
    version=$("$BOOTSTRAP_DART" --version 2>&1)
    ok "Bootstrapping SDK installed: $version"
  else
    fail "SDK download succeeded but dart binary not found"
    return 1
  fi
}

do_setup() {
  echo "=== Setting Up Dart SDK Dev Environment ==="
  echo ""
  echo "SDK root: $SDK_ROOT"
  echo ""

  if [[ "$(uname)" == "Darwin" ]]; then
    if ! xcode-select -p &>/dev/null; then
      echo "Installing Xcode command-line tools..."
      xcode-select --install
      echo "Please complete the Xcode tools installation, then re-run this script."
      exit 1
    fi
    ok "Xcode command-line tools present"
  fi

  install_depot_tools
  install_bootstrap_sdk

  echo ""
  ok "Setup complete!"
  echo ""
  echo "Next steps:"
  echo "  Lightweight (analysis only): bash $(dirname "$0")/fetch_deps.sh"
  echo "  Full build:                  bash $0 gclient"
}

# ---- gclient sync ----

do_gclient() {
  echo "=== Setting Up gclient Workspace ==="
  echo ""

  # Ensure depot_tools in PATH
  if ! command -v gclient &>/dev/null; then
    if [ -d "$DEPOT_TOOLS_DIR" ] && [ -f "$DEPOT_TOOLS_DIR/gclient" ]; then
      export PATH="$DEPOT_TOOLS_DIR:$PATH"
    else
      fail "depot_tools not found. Run 'setup.sh setup' first."
      exit 1
    fi
  fi
  ok "depot_tools found: $(which gclient)"

  local parent_dir
  parent_dir="$(dirname "$SDK_ROOT")"
  local checkout_name
  checkout_name="$(basename "$SDK_ROOT")"
  local workspace_dir=""

  if [ -f "$parent_dir/.gclient" ]; then
    ok ".gclient file already exists at $parent_dir/.gclient"
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
    ok "Created .gclient at $parent_dir/.gclient"
    workspace_dir="$parent_dir"
  else
    # Checkout not named 'sdk' — create wrapper directory with symlink
    workspace_dir="$parent_dir/dart-sdk-workspace"
    if [ -d "$workspace_dir" ] && [ -L "$workspace_dir/sdk" ]; then
      ok "Workspace already exists at $workspace_dir"
    else
      echo "Checkout is named '$checkout_name', not 'sdk'."
      echo "Creating workspace at $workspace_dir with symlink..."
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
      ok "Created workspace at $workspace_dir"
      ok "Symlinked $workspace_dir/sdk -> $SDK_ROOT"
    fi
  fi

  echo ""
  echo "Running gclient sync from $workspace_dir..."
  echo "This downloads all dependencies (C++ libs, Dart packages, tools)."
  echo "First run may take 10-30 minutes."
  echo ""

  cd "$workspace_dir"
  gclient sync -D

  echo ""
  ok "gclient sync complete!"
  echo ""
  echo "Next: bash $0 build"
}

# ---- Build ----

do_build() {
  echo "=== Building the Dart SDK ==="
  echo ""

  if [ ! -f "$SDK_ROOT/tools/build.py" ]; then
    fail "tools/build.py not found at $SDK_ROOT"
    exit 1
  fi

  local mode="${BUILD_MODE:-release}"
  local target="${BUILD_TARGET:-most}"

  echo "Mode: $mode"
  echo "Target: $target"
  echo ""

  python3 "$SDK_ROOT/tools/build.py" --mode "$mode" "$target"

  echo ""
  ok "Build complete!"
}

# ---- Test ----

do_test() {
  local suite="${1:-}"
  if [ -z "$suite" ]; then
    fail "Usage: bash $0 test <suite>"
    echo "  Examples:"
    echo "    bash $0 test language/record_spreads"
    echo "    bash $0 test language"
    echo "    bash $0 test corelib"
    exit 1
  fi

  echo "=== Running Tests: $suite ==="
  echo ""

  if [ ! -f "$SDK_ROOT/tools/test.py" ]; then
    fail "tools/test.py not found"
    exit 1
  fi

  python3 "$SDK_ROOT/tools/test.py" -mrelease --runtime=vm "$suite"
}

# ---- Main ----

case "${1:-help}" in
  check)   do_check ;;
  setup)   do_setup ;;
  gclient) do_gclient ;;
  build)   do_build ;;
  test)    do_test "${2:-}" ;;
  *)
    echo "Usage: bash $0 {check|setup|gclient|build|test <suite>}"
    echo ""
    echo "  check   — diagnose what's missing"
    echo "  setup   — install depot_tools + bootstrapping SDK"
    echo "  gclient — set up gclient workspace + sync all deps"
    echo "  build   — build the SDK (release mode)"
    echo "  test    — run tests via test.py"
    ;;
esac
