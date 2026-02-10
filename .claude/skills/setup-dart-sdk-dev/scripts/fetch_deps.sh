#!/usr/bin/env bash
# Fetch the Dart third_party dependencies needed for package_config.json.
# This is a lightweight alternative to full `gclient sync` when you only need
# to run `dart analyze` / `dart test` on packages under pkg/.
# NOTE: The Dart SDK does NOT use `dart pub get`. Package resolution is done
# via `python3 tools/generate_package_config.py`.
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
DEPOT_TOOLS="${DEPOT_TOOLS_DIR:-$HOME/depot_tools}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

clone_dep() {
  local path="$SDK_ROOT$1"
  local url="$2"
  local rev="$3"

  if [ -d "$path/.git" ]; then
    # Already cloned, just fetch and checkout the right revision
    echo "  Updating $1..."
    cd "$path"
    git fetch origin "$rev" --depth=1 2>/dev/null || git fetch origin --depth=1 2>/dev/null || true
    git checkout "$rev" 2>/dev/null || git checkout FETCH_HEAD 2>/dev/null || true
    cd "$SDK_ROOT"
  else
    echo "  Cloning $1..."
    mkdir -p "$(dirname "$path")"
    git clone --depth=1 "$url" "$path" 2>/dev/null || {
      # If shallow clone fails, try full clone
      git clone "$url" "$path" 2>/dev/null
    }
    cd "$path"
    git checkout "$rev" 2>/dev/null || true
    cd "$SDK_ROOT"
  fi
}

echo "=== Fetching Dart SDK third_party dependencies ==="
echo "SDK root: $SDK_ROOT"
echo ""

# ---- third_party/pkg/* (git repos) ----
echo "Fetching third_party/pkg/* packages..."

clone_dep "/third_party/pkg/ai" "https://dart.googlesource.com/ai.git" "25a627892f5f398dabf78b91d20ac151f7be2b05"
clone_dep "/third_party/pkg/core" "https://dart.googlesource.com/core.git" "cbb485437c61d37753bcc98818beca54d5b38f69"
clone_dep "/third_party/pkg/dart_style" "https://dart.googlesource.com/dart_style.git" "f624489a5013ec58de469d4fd8793c283f62b5d8"
clone_dep "/third_party/pkg/dartdoc" "https://dart.googlesource.com/dartdoc.git" "af0085039035557c792b2d08965e24c2dd342d63"
clone_dep "/third_party/pkg/ecosystem" "https://dart.googlesource.com/ecosystem.git" "eac66d93142907b39f2271647c111f36ff3365b9"
clone_dep "/third_party/pkg/http" "https://dart.googlesource.com/http.git" "a22386e9c390290c916d1c53a3d3c1447ec120ce"
clone_dep "/third_party/pkg/i18n" "https://dart.googlesource.com/i18n.git" "dd8a792a8492370a594706c8304d2eb8db844d7a"
clone_dep "/third_party/pkg/leak_tracker" "https://dart.googlesource.com/leak_tracker.git" "f5620600a5ce1c44f65ddaa02001e200b096e14c"
clone_dep "/third_party/pkg/material_color_utilities" "https://dart.googlesource.com/external/github.com/material-foundation/material-color-utilities.git" "799b6ba2f3f1c28c67cc7e0b4f18e0c7d7f3c03e"
clone_dep "/third_party/pkg/native" "https://dart.googlesource.com/native.git" "0819678f481c1e69d9c62ecf8b0449978ae21c0a"
clone_dep "/third_party/pkg/protobuf" "https://dart.googlesource.com/protobuf.git" "9e30258e0aa6a6430ee36c84b75308a9702fde42"
clone_dep "/third_party/pkg/pub" "https://dart.googlesource.com/pub.git" "26c6985c742593d081f8b58450f463a584a4203a"
clone_dep "/third_party/pkg/shelf" "https://dart.googlesource.com/shelf.git" "dd830a0338b31bee92fe7ebc20b9bb963403b6b0"
clone_dep "/third_party/pkg/sync_http" "https://dart.googlesource.com/sync_http.git" "6666fff944221891182e1f80bf56569338164d72"
clone_dep "/third_party/pkg/tar" "https://dart.googlesource.com/external/github.com/simolus3/tar.git" "13479f7c2a18f499e840ad470cfcca8c579f6909"
clone_dep "/third_party/pkg/test" "https://dart.googlesource.com/test.git" "f95c0f5c10fa9af35014117cb00ec17d2a117265"
clone_dep "/third_party/pkg/tools" "https://dart.googlesource.com/tools.git" "93bf967097d251a4d43d4ae65ea047fe3e7f7fa7"
clone_dep "/third_party/pkg/vector_math" "https://dart.googlesource.com/external/github.com/google/vector_math.dart.git" "70a9a2cb610d040b247f3ca2cd70a94c1c6f6f23"
clone_dep "/third_party/pkg/webdev" "https://dart.googlesource.com/webdev.git" "234e44c2ba0aa6cee5a36026538ca89457bf0d55"
clone_dep "/third_party/pkg/webdriver" "https://dart.googlesource.com/external/github.com/google/webdriver.dart.git" "09104f459ed834d48b132f6b7734923b1fbcf2e9"
clone_dep "/third_party/pkg/webkit_inspection_protocol" "https://dart.googlesource.com/external/github.com/google/webkit_inspection_protocol.dart.git" "0f7685804d77ec02c6564d7ac1a6c8a2341c5bdf"
clone_dep "/third_party/pkg/web" "https://dart.googlesource.com/web.git" "35fc98dd8f9da175ed0a2dcf246299e922e1e1e2"

echo ""

# ---- third_party/devtools (CIPD package) ----
echo "Fetching third_party/devtools via CIPD..."
CIPD="${DEPOT_TOOLS}/cipd"
if [ -x "$CIPD" ]; then
  "$CIPD" ensure \
    -root "$SDK_ROOT/third_party/devtools" \
    -ensure-file - <<CIPD_EOF
dart/third_party/flutter/devtools git_revision:b9d7fc1a4119b3d214a77939f9d75b0c0b25d36a
CIPD_EOF
  ok "devtools installed"
else
  warn "cipd not found at $CIPD — skipping devtools (needed for full pub resolution)"
fi

echo ""
echo "=== Generating package config ==="
BOOTSTRAP_DART="$SDK_ROOT/tools/sdks/dart-sdk/bin/dart"
if [ -x "$BOOTSTRAP_DART" ]; then
  python3 "$SDK_ROOT/tools/generate_package_config.py" && ok "package_config.json generated" || {
    fail "generate_package_config.py failed. Check that all third_party/pkg/ deps are present."
    exit 1
  }
else
  fail "Bootstrapping SDK not found. Run the setup skill first."
  exit 1
fi

echo ""
ok "Done! Dependencies fetched."
