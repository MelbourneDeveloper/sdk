---
name: setup-dart-sdk-dev
description: Set up the Dart SDK development environment for analysis and package-level testing. Fetches third_party dependencies and generates package_config.json.
disable-model-invocation: true
allowed-tools: Bash
---

# Set Up Dart SDK Development Environment (Analysis & Package Tests)

Read [docs/Building.md](../../../docs/Building.md) for the full official documentation.

## Critical things to know

- **Never use `dart pub get`** — it will always fail. The SDK uses
  `python3 tools/generate_package_config.py` for package resolution.
- **`sdk/bin/dart`** is NOT a usable binary — it's a wrapper that only works
  after a full SDK build. Use `tools/sdks/dart-sdk/bin/dart` (the bootstrapping
  SDK) instead.

## Quick diagnostic

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh check
```

## Full setup

### Step 1: Install depot_tools + bootstrapping SDK

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh setup
```

### Step 2: Fetch third_party deps + generate package_config.json

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/fetch_deps.sh
```

## After setup

```bash
./tools/sdks/dart-sdk/bin/dart analyze pkg/front_end
./tools/sdks/dart-sdk/bin/dart analyze pkg/analyzer
```

## Troubleshooting

- **"SDK version" errors**: Don't use pub get. Run
  `python3 tools/generate_package_config.py`.
- **Missing packages**: Re-run `fetch_deps.sh`, then `generate_package_config.py`.
- **Need to build the full SDK or run test.py**: See the `build-and-test-dart-sdk`
  skill — that requires `gclient sync`.
