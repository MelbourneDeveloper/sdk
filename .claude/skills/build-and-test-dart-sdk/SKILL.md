---
name: build-and-test-dart-sdk
description: Set up gclient sync, build the Dart SDK compilers/VM, and run tests with test.py. Use when you need to build the full SDK or run the SDK test suite (language tests, corelib tests, etc.).
disable-model-invocation: true
allowed-tools: Bash
---

# Build & Test the Dart SDK

Read [docs/Building.md](../../docs/Building.md) and
[docs/Testing.md](../../docs/Testing.md) for full official documentation.

## Prerequisites

- depot_tools installed and in PATH (see `setup-dart-sdk-dev` skill)
- macOS: Xcode (not just command-line tools)

## Step 1: Set up gclient workspace

The DEPS file hardcodes `"dart_root": "sdk"` — the checkout **must** be in a
directory called `sdk/` under the `.gclient` file.

```bash
bash .claude/skills/build-and-test-dart-sdk/scripts/setup_gclient.sh
```

This creates the parent workspace structure and runs `gclient sync`.

## Step 2: Build

```bash
# Build most targets (analysis_server, dart2js, DDC, runtime, create_sdk)
./tools/build.py most

# Or just the VM runtime (fastest)
./tools/build.py runtime

# Release mode
./tools/build.py --mode release create_sdk
```

Output goes to `xcodebuild/` (macOS) or `out/` (Linux/Windows).

## Step 3: Test

Build `most` and `run_ffi_unit_tests` before testing:

```bash
./tools/build.py --mode release most run_ffi_unit_tests
```

Then run tests:

```bash
# VM language tests
./tools/test.py -mrelease --runtime=vm language

# Single test
./tools/test.py -mrelease --runtime=vm corelib/ListTest

# Analyzer tests
./tools/test.py --compiler dart2analyzer --runtime none language

# dart2js tests
./tools/test.py -mrelease --compiler=dart2js --runtime=chrome language
```

See `./tools/test.py --help` for all options.
