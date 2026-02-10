---
name: build-dart-sdk
description: Build the Dart SDK compilers and VM runtime. Use when you need to compile the SDK, build specific targets (runtime, most, create_sdk, dart2js, analysis_server), or troubleshoot build issues.
disable-model-invocation: true
allowed-tools: Bash
---

# Build the Dart SDK

Official docs: [docs/Building.md](../../../docs/Building.md)

## Prerequisites

- depot_tools in PATH (see `setup-dart-sdk-dev` skill)
- gclient workspace synced (see below)
- macOS: Xcode installed (not just command-line tools)

## Quick build

```bash
bash .claude/skills/build-dart-sdk/scripts/build.sh
```

This builds the `most` target in release mode (analysis_server, dart2js, DDC, runtime, create_sdk).

## Build specific targets

```bash
# Just the VM runtime (fastest build)
bash .claude/skills/build-dart-sdk/scripts/build.sh runtime

# Full SDK distribution
bash .claude/skills/build-dart-sdk/scripts/build.sh create_sdk

# Specific compiler
bash .claude/skills/build-dart-sdk/scripts/build.sh dart2js
bash .claude/skills/build-dart-sdk/scripts/build.sh analysis_server

# Multiple targets
bash .claude/skills/build-dart-sdk/scripts/build.sh most run_ffi_unit_tests
```

## Build modes

```bash
# Debug mode (default for development)
bash .claude/skills/build-dart-sdk/scripts/build.sh --mode debug runtime

# Release mode (default for this script)
bash .claude/skills/build-dart-sdk/scripts/build.sh --mode release most
```

## Gclient sync (required before first build)

```bash
bash .claude/skills/build-dart-sdk/scripts/build.sh sync
```

This sets up the gclient workspace and downloads all native dependencies. Required once, then again after pulling new changes that modify DEPS.

## Output directories

| Platform | Debug | Release |
|----------|-------|---------|
| macOS arm64 | `xcodebuild/DebugARM64/` | `xcodebuild/ReleaseARM64/` |
| macOS x64 | `xcodebuild/DebugX64/` | `xcodebuild/ReleaseX64/` |
| Linux/Windows | `out/DebugX64/` | `out/ReleaseX64/` |

## Common build targets

| Target | What it builds | Time |
|--------|---------------|------|
| `runtime` | VM only | Fast |
| `most` | analysis_server, dart2js, DDC, runtime, create_sdk | Medium |
| `create_sdk` | Full SDK distribution | Medium |
| `dart2js` | dart2js compiler only | Medium |
| `analysis_server` | Analysis server only | Medium |
| `run_ffi_unit_tests` | FFI unit tests (needed before running tests) | Fast |

## Troubleshooting

- **No gclient workspace**: Run `bash .claude/skills/build-dart-sdk/scripts/build.sh sync` first
- **Stale deps after branch switch**: Run `gclient sync -D` from the workspace root
- **Xcode errors on macOS**: Ensure full Xcode is installed, not just command-line tools
- **Python errors**: Ensure Python 3 is available as `python3`
