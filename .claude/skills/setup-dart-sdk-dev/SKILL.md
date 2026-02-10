---
name: setup-dart-sdk-dev
description: Set up the Dart SDK development environment — from deps to full builds to running tests. Handles depot_tools, bootstrapping SDK, gclient sync, building, and test.py.
disable-model-invocation: true
allowed-tools: Bash
---

# Set Up Dart SDK Development Environment

Read [docs/Building.md](../../../docs/Building.md) and
[docs/Testing.md](../../../docs/Testing.md) for full official documentation.

## Critical things to know

- **Never use `dart pub get`** — it always fails. The SDK uses
  `python3 tools/generate_package_config.py` for package resolution.
- **`sdk/bin/dart`** is NOT usable — it's a wrapper that only works after a
  full SDK build. Use `tools/sdks/dart-sdk/bin/dart` (bootstrapping SDK).

## Quick diagnostic

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh check
```

## Setup modes

### Lightweight (analysis + package tests only)

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh setup
bash .claude/skills/setup-dart-sdk-dev/scripts/fetch_deps.sh
```

### Full (gclient sync + build + test.py)

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh setup
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh gclient
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh build
```

### Run tests

```bash
# Run specific language tests
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh test language/record_spreads

# Run all language tests
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh test language

# Run corelib tests
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh test corelib
```

## After setup (lightweight mode)

```bash
./tools/sdks/dart-sdk/bin/dart analyze pkg/front_end
./tools/sdks/dart-sdk/bin/dart analyze pkg/analyzer
```

## Troubleshooting

- **"SDK version" errors**: Don't use pub get. Run
  `python3 tools/generate_package_config.py`.
- **Missing packages**: Re-run `fetch_deps.sh`, then `generate_package_config.py`.
- **Can't run test.py**: You need a full build. Run `setup.sh gclient` then
  `setup.sh build`.
