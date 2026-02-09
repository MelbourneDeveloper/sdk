#!/usr/bin/env bash
# Setup script for Dart SDK development environment.
# Usage:
#   bash setup.sh check   — diagnose what's missing
#   bash setup.sh setup   — install/configure everything needed

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEPOT_TOOLS_DIR="${DEPOT_TOOLS_DIR:-$HOME/depot_tools}"
SDK_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
BOOTSTRAP_DART="$SDK_ROOT/tools/sdks/dart-sdk/bin/dart"

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

check_gclient_config() {
  if [ -f "$SDK_ROOT/.gclient" ]; then
    ok ".gclient config exists"
    return 0
  else
    fail ".gclient not configured"
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
  check_gclient_config || ((issues++)) || true
  check_bootstrap_sdk  || ((issues++)) || true

  echo ""
  if [ "$issues" -eq 0 ]; then
    ok "Environment looks good. Use the bootstrapping SDK for pub operations:"
    echo "    $BOOTSTRAP_DART pub get"
  else
    warn "$issues issue(s) found. Run 'bash $0 setup' to fix."
  fi
}

install_depot_tools() {
  if command -v gclient &>/dev/null; then
    ok "depot_tools already in PATH"
    return 0
  fi

  if [ ! -d "$DEPOT_TOOLS_DIR" ]; then
    echo "Cloning depot_tools to $DEPOT_TOOLS_DIR..."
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
  else
    ok "depot_tools directory already exists at $DEPOT_TOOLS_DIR"
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

configure_gclient() {
  if [ -f "$SDK_ROOT/.gclient" ]; then
    ok ".gclient already configured"
    return 0
  fi

  echo "Configuring gclient..."
  cd "$SDK_ROOT"
  gclient config https://dart.googlesource.com/sdk.git
  ok ".gclient configured"
}

run_gclient_sync() {
  echo "Running gclient sync (this may take a while)..."
  cd "$SDK_ROOT"
  gclient sync
  ok "gclient sync complete"
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
  configure_gclient
  run_gclient_sync

  echo ""
  echo "=== Verifying ==="
  check_bootstrap_sdk

  echo ""
  ok "Setup complete! Use the bootstrapping SDK:"
  echo "    $BOOTSTRAP_DART pub get"
}

case "${1:-help}" in
  check) do_check ;;
  setup) do_setup ;;
  *)
    echo "Usage: bash $0 {check|setup}"
    echo ""
    echo "  check  — diagnose what's missing"
    echo "  setup  — install/configure everything"
    ;;
esac
