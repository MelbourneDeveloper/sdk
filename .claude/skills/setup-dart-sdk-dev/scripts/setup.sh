#!/usr/bin/env bash
# Setup script for Dart SDK development environment.
# Usage:
#   bash setup.sh check   — diagnose what's missing
#   bash setup.sh setup   — install depot_tools + bootstrapping SDK

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
  # Check key packages exist (some are monorepos without top-level pubspec.yaml)
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
  check_xcode_tools    || ((issues++)) || true
  check_depot_tools    || ((issues++)) || true
  check_bootstrap_sdk  || ((issues++)) || true
  check_third_party    || ((issues++)) || true
  check_package_config || ((issues++)) || true

  echo ""
  if [ "$issues" -eq 0 ]; then
    ok "Environment looks good. Use the bootstrapping SDK:"
    echo "    $BOOTSTRAP_DART analyze pkg/front_end"
    echo "    $BOOTSTRAP_DART analyze pkg/analyzer"
    echo ""
    echo "  NOTE: Do NOT use 'dart pub get'. Use this instead:"
    echo "    python3 $SDK_ROOT/tools/generate_package_config.py"
  else
    warn "$issues issue(s) found. Run 'bash $0 setup' to fix."
  fi
}

install_depot_tools() {
  if [ -d "$DEPOT_TOOLS_DIR" ] && [ -f "$DEPOT_TOOLS_DIR/cipd" ]; then
    ok "depot_tools already exists at $DEPOT_TOOLS_DIR"
  else
    echo "Cloning depot_tools to $DEPOT_TOOLS_DIR..."
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
  fi

  # Add to PATH for this session
  export PATH="$DEPOT_TOOLS_DIR:$PATH"

  # Persist to shell profile
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

  # Extract SDK CIPD tag from DEPS
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
  echo "Next step: fetch third_party dependencies:"
  echo "    bash $(dirname "$0")/fetch_deps.sh"
}

case "${1:-help}" in
  check) do_check ;;
  setup) do_setup ;;
  *)
    echo "Usage: bash $0 {check|setup}"
    echo ""
    echo "  check  — diagnose what's missing"
    echo "  setup  — install depot_tools + bootstrapping SDK"
    ;;
esac
