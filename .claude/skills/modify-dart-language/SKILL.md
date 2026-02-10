---
name: modify-dart-language
description: Guide for modifying the Dart language — adding features, AST nodes, parser rules, CFE type inference, experimental flags, and diagnostics. Use when implementing or modifying Dart language features.
---

# Modifying the Dart Language

## Compiler pipeline

```
Source → _fe_analyzer_shared (scan+parse) → front_end (type-check) → kernel IR
                                                    ↓
              ┌─────────────────────────────────────┼───────────────────┐
              ↓                                     ↓                   ↓
    pkg/compiler (dart2js)              runtime/vm/compiler      pkg/dart2wasm
    → JavaScript                        → native code            → WebAssembly
```

All backends share the same front-end. Language changes typically touch:
1. Parser (`pkg/_fe_analyzer_shared/`)
2. CFE type inference (`pkg/front_end/`)
3. Analyzer AST (`pkg/analyzer/`)
4. Tests (`tests/language/`)

## Key files by subsystem

| Subsystem | Key file | Purpose |
|-----------|----------|---------|
| Experimental flags | `tools/experimental_features.yaml` | Gate new features |
| Scanner/tokens | `pkg/_fe_analyzer_shared/lib/src/scanner/` | Tokenization |
| Parser | `pkg/_fe_analyzer_shared/lib/src/parser/parser_impl.dart` | Parsing |
| Parser listener | `pkg/_fe_analyzer_shared/lib/src/parser/listener.dart` | Parser events |
| CFE body builder | `pkg/front_end/lib/src/kernel/body_builder.dart` | Type inference + Kernel IR |
| CFE messages | `pkg/front_end/messages.yaml` | Diagnostic messages |
| Analyzer AST | `pkg/analyzer/lib/src/dart/ast/ast.dart` | AST node definitions |
| Analyzer visitors | `pkg/analyzer/lib/dart/ast/visitor.dart` | AST traversal |
| Language tests | `tests/language/` | Language feature tests |

## Adding an experimental feature

1. Add entry to `tools/experimental_features.yaml`:
   ```yaml
   my-feature:
     help: "Short description of the feature."
   ```

2. Regenerate flags:
   ```bash
   ./tools/sdks/dart-sdk/bin/dart pkg/front_end/tool/cfe.dart generate-experimental-flags
   ```

3. Gate parser/CFE code with the experiment flag.

## Subsystem reference docs

- **Analyzer AST patterns**: [ast-patterns.md](ast-patterns.md) — adding AST nodes, visitor methods
- **CFE patterns**: [cfe-patterns.md](cfe-patterns.md) — body builder, diagnostics, Kernel IR
- **Parser patterns**: [parser-patterns.md](parser-patterns.md) — parser methods, listener events

## Code generation steps

After modifying AST nodes or messages, run the appropriate generators:

```bash
# After editing messages.yaml
./tools/sdks/dart-sdk/bin/dart pkg/front_end/tool/generate_messages.dart

# After editing experimental_features.yaml
./tools/sdks/dart-sdk/bin/dart pkg/front_end/tool/cfe.dart generate-experimental-flags

# After editing analyzer AST (regenerate visitors etc.)
./tools/sdks/dart-sdk/bin/dart pkg/analyzer/tool/generate_nodes.dart

# After editing parser tests
./tools/sdks/dart-sdk/bin/dart pkg/front_end/tool/update_expectations.dart
```

## Typical feature implementation order

1. Add experimental flag
2. Parser changes (scan, parse, listener events)
3. CFE changes (body builder, type inference, Kernel IR generation)
4. Analyzer AST changes (nodes, visitors, resolution)
5. Diagnostic messages
6. Language tests
7. Update static error test expectations
