---
name: setup-dart-sdk-dev
description: Set up the Dart SDK development environment. Installs depot_tools, fetches the bootstrapping SDK and third_party dependencies, and generates package_config.json. Use when getting "SDK version" errors from dart pub get, or when setting up a fresh Dart SDK checkout.
disable-model-invocation: true
allowed-tools: Bash
---

# Set Up Dart SDK Development Environment

The Dart SDK monorepo requires a bootstrapping SDK and third_party dependencies that are NOT included in the git checkout. If you see errors like "requires SDK version ^3.x.0-0" from `dart pub get`, the environment isn't set up correctly.

**Do NOT use your system `dart` for this repo.** Use the bootstrapping SDK at `tools/sdks/dart-sdk/bin/dart`.

## Quick diagnostic

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh check
```

## Full setup (two steps)

### Step 1: Install depot_tools + bootstrapping SDK

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh setup
```

This installs depot_tools (if missing) and downloads the bootstrapping SDK via CIPD.

### Step 2: Fetch third_party Dart dependencies

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/fetch_deps.sh
```

This clones the ~22 Dart packages under `third_party/pkg/` and `third_party/devtools/` needed for pub resolution, then runs `generate_package_config.py` to create `.dart_tool/package_config.json`.

## Important notes

- **gclient sync is NOT required** for basic Dart development (analysis, tests on pkg/). The `fetch_deps.sh` script fetches only the Dart packages needed for pub resolution, skipping heavy C++ deps (boringssl, icu, binaryen, etc.)
- **gclient sync IS required** if you need to build the full SDK (compilers, VM, etc.)
- The bootstrapping SDK version may be older than the repo's SDK constraint, but `generate_package_config.py` handles this correctly
- If you need to update deps after rebasing, re-run `fetch_deps.sh`

## After setup

Use the bootstrapping SDK:

```bash
./tools/sdks/dart-sdk/bin/dart analyze pkg/front_end
./tools/sdks/dart-sdk/bin/dart test pkg/analyzer
```

Or add an alias:

```bash
alias dart-sdk='./tools/sdks/dart-sdk/bin/dart'
```

## Full gclient sync (optional, for full SDK builds)

If you need a full build environment:

1. Create a parent workspace with the proper `sdk/` directory structure
2. The Dart SDK DEPS file hardcodes `"dart_root": "sdk"` — the checkout MUST be in a directory called `sdk/` under the `.gclient` file
3. Run `gclient sync` from the parent directory

See [scripts/setup.sh](scripts/setup.sh) and [scripts/fetch_deps.sh](scripts/fetch_deps.sh) for details.

## Troubleshooting

- If `cipd` commands fail, ensure depot_tools is installed: `bash scripts/setup.sh setup`
- On macOS, Xcode command-line tools are required: `xcode-select --install`
- If `generate_package_config.py` fails with missing packages, re-run `fetch_deps.sh`
- Dependency revisions in `fetch_deps.sh` are pinned to specific DEPS entries — update them if the DEPS file changes
