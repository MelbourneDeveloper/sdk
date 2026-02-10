#!/usr/bin/env bash
# Fetch the Dart third_party dependencies needed for package_config.json.
# This is a lightweight alternative to full `gclient sync` when you only need
# to run `dart analyze` / `dart test` on packages under pkg/.
#
# Revisions are read dynamically from the DEPS file so this script never goes
# stale when DEPS is updated.
#
# NOTE: The Dart SDK does NOT use `dart pub get`. Package resolution is done
# via `python3 tools/generate_package_config.py`.
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
DEPOT_TOOLS="${DEPOT_TOOLS_DIR:-$HOME/depot_tools}"
DEPS_FILE="$SDK_ROOT/DEPS"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Parse a _rev variable from the DEPS file.
# Usage: get_rev "native_rev"  =>  prints the 40-char git hash
get_rev() {
  local var_name="$1"
  local rev
  rev=$(grep "\"${var_name}\":" "$DEPS_FILE" | head -1 | sed 's/.*"\([0-9a-f]\{40\}\)".*/\1/')
  if [ -z "$rev" ] || [ ${#rev} -ne 40 ]; then
    fail "Could not parse ${var_name} from DEPS"
    return 1
  fi
  echo "$rev"
}

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

if [ ! -f "$DEPS_FILE" ]; then
  fail "DEPS file not found at $DEPS_FILE"
  exit 1
fi

echo "=== Fetching Dart SDK third_party dependencies ==="
echo "SDK root: $SDK_ROOT"
echo "Reading revisions from DEPS..."
echo ""

# ---- Read revisions from DEPS ----
DART_GIT="https://dart.googlesource.com/"

ai_rev=$(get_rev "ai_rev")
core_rev=$(get_rev "core_rev")
dart_style_rev=$(get_rev "dart_style_rev")
dartdoc_rev=$(get_rev "dartdoc_rev")
ecosystem_rev=$(get_rev "ecosystem_rev")
http_rev=$(get_rev "http_rev")
i18n_rev=$(get_rev "i18n_rev")
leak_tracker_rev=$(get_rev "leak_tracker_rev")
material_color_utilities_rev=$(get_rev "material_color_utilities_rev")
native_rev=$(get_rev "native_rev")
protobuf_rev=$(get_rev "protobuf_rev")
pub_rev=$(get_rev "pub_rev")
shelf_rev=$(get_rev "shelf_rev")
sync_http_rev=$(get_rev "sync_http_rev")
tar_rev=$(get_rev "tar_rev")
test_rev=$(get_rev "test_rev")
tools_rev=$(get_rev "tools_rev")
vector_math_rev=$(get_rev "vector_math_rev")
webdev_rev=$(get_rev "webdev_rev")
webdriver_rev=$(get_rev "webdriver_rev")
webkit_inspection_protocol_rev=$(get_rev "webkit_inspection_protocol_rev")
web_rev=$(get_rev "web_rev")
devtools_rev=$(get_rev "devtools_rev")

# ---- third_party/pkg/* (git repos) ----
echo "Fetching third_party/pkg/* packages..."

clone_dep "/third_party/pkg/ai" "${DART_GIT}ai.git" "$ai_rev"
clone_dep "/third_party/pkg/core" "${DART_GIT}core.git" "$core_rev"
clone_dep "/third_party/pkg/dart_style" "${DART_GIT}dart_style.git" "$dart_style_rev"
clone_dep "/third_party/pkg/dartdoc" "${DART_GIT}dartdoc.git" "$dartdoc_rev"
clone_dep "/third_party/pkg/ecosystem" "${DART_GIT}ecosystem.git" "$ecosystem_rev"
clone_dep "/third_party/pkg/http" "${DART_GIT}http.git" "$http_rev"
clone_dep "/third_party/pkg/i18n" "${DART_GIT}i18n.git" "$i18n_rev"
clone_dep "/third_party/pkg/leak_tracker" "${DART_GIT}leak_tracker.git" "$leak_tracker_rev"
clone_dep "/third_party/pkg/material_color_utilities" "${DART_GIT}external/github.com/material-foundation/material-color-utilities.git" "$material_color_utilities_rev"
clone_dep "/third_party/pkg/native" "${DART_GIT}native.git" "$native_rev"
clone_dep "/third_party/pkg/protobuf" "${DART_GIT}protobuf.git" "$protobuf_rev"
clone_dep "/third_party/pkg/pub" "${DART_GIT}pub.git" "$pub_rev"
clone_dep "/third_party/pkg/shelf" "${DART_GIT}shelf.git" "$shelf_rev"
clone_dep "/third_party/pkg/sync_http" "${DART_GIT}sync_http.git" "$sync_http_rev"
clone_dep "/third_party/pkg/tar" "${DART_GIT}external/github.com/simolus3/tar.git" "$tar_rev"
clone_dep "/third_party/pkg/test" "${DART_GIT}test.git" "$test_rev"
clone_dep "/third_party/pkg/tools" "${DART_GIT}tools.git" "$tools_rev"
clone_dep "/third_party/pkg/vector_math" "${DART_GIT}external/github.com/google/vector_math.dart.git" "$vector_math_rev"
clone_dep "/third_party/pkg/webdev" "${DART_GIT}webdev.git" "$webdev_rev"
clone_dep "/third_party/pkg/webdriver" "${DART_GIT}external/github.com/google/webdriver.dart.git" "$webdriver_rev"
clone_dep "/third_party/pkg/webkit_inspection_protocol" "${DART_GIT}external/github.com/google/webkit_inspection_protocol.dart.git" "$webkit_inspection_protocol_rev"
clone_dep "/third_party/pkg/web" "${DART_GIT}web.git" "$web_rev"

echo ""

# ---- third_party/devtools (CIPD package) ----
echo "Fetching third_party/devtools via CIPD..."
CIPD="${DEPOT_TOOLS}/cipd"
if [ -x "$CIPD" ]; then
  "$CIPD" ensure \
    -root "$SDK_ROOT/third_party/devtools" \
    -ensure-file - <<CIPD_EOF
dart/third_party/flutter/devtools git_revision:${devtools_rev}
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
ok "Done! Dependencies fetched (revisions read from DEPS)."
