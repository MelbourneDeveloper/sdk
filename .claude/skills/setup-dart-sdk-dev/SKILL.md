---
name: setup-dart-sdk-dev
description: Set up the Dart SDK development environment. Installs depot_tools, runs gclient sync, and configures the bootstrapping SDK. Use when getting "SDK version" errors from dart pub get, or when setting up a fresh Dart SDK checkout.
disable-model-invocation: true
allowed-tools: Bash
---

# Set Up Dart SDK Development Environment

The Dart SDK monorepo requires a bootstrapping SDK (downloaded via `gclient sync`) rather than your system-installed Dart. If you see errors like "requires SDK version ^3.x.0-0" from `dart pub get`, the environment isn't set up correctly.

## Quick diagnostic

Run the diagnostic script to check what's missing:

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh check
```

## Full setup

Run the full setup to install everything needed:

```bash
bash .claude/skills/setup-dart-sdk-dev/scripts/setup.sh setup
```

## What this does

1. **Checks for depot_tools** — clones it to `~/depot_tools` if missing
2. **Ensures PATH includes depot_tools** — adds it to your shell profile
3. **Configures gclient** — creates `.gclient` if needed for this checkout
4. **Runs `gclient sync`** — downloads all dependencies including the bootstrapping SDK
5. **Verifies the bootstrapping SDK** — confirms `tools/sdks/dart-sdk/bin/dart` exists and reports its version

## After setup

Once set up, use the repo's bootstrapping SDK for pub operations:

```bash
./tools/sdks/dart-sdk/bin/dart pub get
```

Or add an alias to your shell profile:

```bash
alias dart-sdk='./tools/sdks/dart-sdk/bin/dart'
```

## Troubleshooting

- If `gclient sync` fails with auth errors, run `gclient auth-login` first
- If the bootstrapping SDK is missing after sync, check `tools/sdks/` — the SDK is downloaded via CIPD during sync
- On macOS, Xcode command-line tools are required: `xcode-select --install`
- For detailed reference, see [scripts/setup.sh](scripts/setup.sh)
