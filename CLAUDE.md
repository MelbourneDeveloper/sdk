# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Rules

- Do not use Git
- Follow the conventions of the repo and compiler
- #1 Priority: no duplication

## Critical Docs

- [Dart SDK](https://dart.dev/tools/sdk)
- [Building Dart](docs/Building.md)
- [Testing Dart](docs/Testing.md)

## Too Many Cooks

- Register immediately
- Signal intent with plans, messages and locks; listen to the intent of others

## Repository Overview

This is the **Dart SDK** monorepo — the complete source for the Dart programming language, including compilers, VM runtime, core libraries, analysis tools, and developer tooling.

## Build System

The SDK uses **GN + Ninja** for building (not Make/CMake). Dependencies are managed via `gclient` (depot_tools), not git submodules.

### Common Build Commands

```bash
# Build the VM runtime only (fastest, default target)
./tools/build.py runtime

# Build most of the SDK (analysis_server, dart2js, DDC, runtime, create_sdk)
./tools/build.py most

# Full SDK distribution
./tools/build.py create_sdk

# Specific targets
./tools/build.py dart2js
./tools/build.py analysis_server

# Release mode (default is debug)
./tools/build.py -m release create_sdk

# Specify architecture
./tools/build.py -a arm64 -m release create_sdk
```

**Output directories:**
- macOS: `xcodebuild/{Debug,Release}{X64,ARM64}/`
- Linux/Windows: `out/{Debug,Release}{X64,ARM64}/`

### Running Tests

Test runner: `./tools/test.py` (requires a build first).

```bash
# Run language tests on the VM
./tools/test.py -mrelease --runtime=vm language

# Run a single test
./tools/test.py -mrelease --runtime=vm corelib/ListTest

# Run core library tests
./tools/test.py -mrelease --runtime=vm corelib

# Run with dart2js targeting Chrome
./tools/test.py -mrelease --compiler=dart2js --runtime=chrome language

# Run analyzer tests
./tools/test.py --compiler=dart2analyzer --runtime=none language
```

Key test runner flags: `--compiler` (dartk, dart2js, dart2analyzer, ddc, none), `--runtime` (vm, d8, chrome, firefox, none), `-m` (debug/release), `--progress color`.

### Running Dart Package Tests

For pure-Dart packages under `pkg/`, you can also run tests directly:

```bash
dart test pkg/<package_name>
dart analyze pkg/<package_name>
```

## Architecture

### Compiler Pipeline

All Dart backends share a common front-end:

```
Source Code → pkg/front_end (parse + type-check) → pkg/kernel (Kernel IR)
                                                        ↓
                    ┌───────────────────────────────────┼──────────────────────┐
                    ↓                                   ↓                      ↓
          pkg/compiler (dart2js)              runtime/vm/compiler        pkg/dart2wasm
          → JavaScript output               → native machine code       → WebAssembly
                    ↓
          pkg/dev_compiler (DDC)
          → ES6 modules (dev builds)
```

### Key Packages (`pkg/`)

| Package | Purpose |
|---------|---------|
| `front_end` | Shared compiler front-end: parsing, type-checking → Kernel IR |
| `kernel` | Kernel intermediate representation (the central IR for all backends) |
| `compiler` | dart2js: production JavaScript compiler (closed-world, tree-shaking, global type inference) |
| `dev_compiler` | DDC: modular dev-time JS compiler producing ES6 modules |
| `dart2wasm` | WebAssembly compiler backend |
| `analyzer` | Static analysis engine (published to pub.dev, used by IDEs) |
| `analysis_server` | LSP/legacy protocol server for IDE integration |
| `_fe_analyzer_shared` | Shared code between `front_end` and `analyzer` (scanner, parser) |
| `linter` | Dart lint rules |
| `frontend_server` | Incremental compilation server (used by Flutter hot reload) |
| `vm_service` | Client library for VM Service Protocol (debugging) |
| `dds` | Dart Developer Service (extends VM Service) |
| `dartdev` | The `dart` CLI tool implementation |
| `test_runner` | SDK test harness infrastructure |

### Runtime (`runtime/`)

C++ implementation of the Dart VM:
- `runtime/vm/compiler/` — JIT and AOT compilation pipelines (frontend → IL flow graphs → architecture-specific codegen)
- `runtime/vm/heap/` — Garbage collector
- `runtime/vm/isolate.cc` — Isolate management
- `runtime/vm/object.cc` — Core object representation
- `runtime/vm/service/` — VM Service debug protocol
- Architecture-specific code for ARM, ARM64, x64, RISC-V, IA32

### SDK Libraries (`sdk/lib/`)

The Dart standard library: `core`, `async`, `io`, `collection`, `convert`, `math`, `ffi`, `js_interop`, etc. Platform-specific internals live in `_internal/`, `_vm/`, `_wasm/`.

### Tests (`tests/`)

- `language/` — Language feature tests
- `corelib/` — Core library tests
- `lib/` — SDK library tests
- `standalone/` — Standalone VM tests
- `web/` — Web-specific tests
- `ffi/` — Foreign function interface tests
- `co19/` — Dart spec compliance tests

## Code Review Workflow

This project uses **Gerrit** (dart-review.googlesource.com) for code review, not GitHub PRs. GitHub PRs are auto-converted to Gerrit CLs by a copybara bot. Branch management uses depot_tools: `git new-branch`, `git cl upload`, `git rebase-update`.

## Style

- **C++ code** (runtime/): Google C++ Style Guide
- **Dart code** (pkg/, sdk/): Effective Dart style guide
- Analysis options configured per-package via `analysis_options.yaml`
