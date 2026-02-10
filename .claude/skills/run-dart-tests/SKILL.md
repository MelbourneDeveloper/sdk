---
name: run-dart-tests
description: Run Dart SDK tests — language tests, corelib tests, analyzer tests, dart2js tests, and package-level tests. Use when running tests after building the SDK or verifying language changes.
disable-model-invocation: true
allowed-tools: Bash
---

# Run Dart SDK Tests

Official docs: [docs/Testing.md](../../../docs/Testing.md)

## Prerequisites

Build `most` and `run_ffi_unit_tests` before running tests:

```bash
bash .claude/skills/build-dart-sdk/scripts/build.sh most run_ffi_unit_tests
```

## Quick test

```bash
# Run VM language tests (most common)
bash .claude/skills/run-dart-tests/scripts/test.sh language

# Run a single test
bash .claude/skills/run-dart-tests/scripts/test.sh language/record_spreads/record_spread_test

# Run corelib tests
bash .claude/skills/run-dart-tests/scripts/test.sh corelib
```

## Test configurations

```bash
# VM tests (default)
bash .claude/skills/run-dart-tests/scripts/test.sh language

# Analyzer tests
bash .claude/skills/run-dart-tests/scripts/test.sh --compiler dart2analyzer language

# dart2js tests
bash .claude/skills/run-dart-tests/scripts/test.sh --compiler dart2js --runtime chrome language

# DDC tests
bash .claude/skills/run-dart-tests/scripts/test.sh --compiler ddc --runtime chrome language
```

## Package-level tests

For pure-Dart packages under `pkg/`, use the bootstrapping SDK directly:

```bash
# Analyze a package
./tools/sdks/dart-sdk/bin/dart analyze pkg/front_end

# Run package tests
./tools/sdks/dart-sdk/bin/dart test pkg/analyzer

# Analyze with experiments enabled
./tools/sdks/dart-sdk/bin/dart analyze --enable-experiment=record-spreads pkg/front_end
```

## Test suites

| Suite | Directory | What it tests |
|-------|-----------|---------------|
| `language` | `tests/language/` | Language feature tests (null-safe) |
| `corelib` | `tests/corelib/` | Core library tests |
| `lib` | `tests/lib/` | SDK library tests |
| `standalone` | `tests/standalone/` | Standalone VM tests |
| `web` | `tests/web/` | Web-specific tests |
| `ffi` | `tests/ffi/` | FFI tests |
| `co19` | `tests/co19/` | Dart spec compliance |

## Update static error test expectations

After changing error messages or locations:

```bash
./tools/sdks/dart-sdk/bin/dart pkg/test_runner/tool/update_static_error_tests.dart -u "**/your_test.dart"
```

## Update parser test expectations

After changing parser behavior:

```bash
./tools/sdks/dart-sdk/bin/dart pkg/front_end/tool/update_expectations.dart
```

For test format details (multitests, static error tests), see [test-formats.md](test-formats.md).
