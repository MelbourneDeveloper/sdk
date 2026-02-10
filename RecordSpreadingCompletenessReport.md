# Record Spreading — Completeness Report

**Issue:** [dart-lang/language#2128](https://github.com/dart-lang/language/issues/2128)
**Branch:** `RecordSpreading` (16 commits, 74 files changed, +6483/−71 lines)
**Date:** 2026-02-10

---

## What the Issue Asks For

@lrhn's proposal: add `...recordExpression` inside record literals (and argument lists) to inline all fields at the spread point. Core rules:

1. **Static-only** — the spread expression must have a concrete record type (not `dynamic`, `Record`, or `T extends Record`), so the compiler knows the exact field shape at compile time.
2. **Record literals:** `(num, num, {Color color}) colorPoint = (...point, color: Color.red);`
3. **Argument lists:** `foo(...record)` to expand record fields as function arguments — @munificent emphatically supported this.
4. **No `if`/`for` in records** — @lrhn explicitly rejected conditionally changing record structure.
5. **No `Destructure_N_` interfaces** — @lrhn rejected; @munificent acquiesced.
6. **No dynamic record operations** — `Record concat(Record a, Record b) => (...a, ...b)` is not allowed.

---

## What's Implemented (Round 1: Record Literal Spreading)

The implementation is a **purely static desugaring**. During type inference, `...record` is expanded into individual field accesses (`record.$1`, `record.$2`, `record.name`, etc.). By the time any backend (VM, dart2js, DDC, dart2wasm) sees the code, it's a normal `RecordLiteral`. **No backend changes were needed.**

### How It Works

```
Source: (...point, color: 'red')
          ↓ Parser
RecordSpreadElement(expression: point, isNullAware: false)
          ↓ Type Inference (_expandRecordSpreads)
Infer point → (int, int)
Hoist: let tmp = point
Expand: tmp.$1, tmp.$2, color: 'red'
          ↓ Result
RecordLiteral(tmp.$1, tmp.$2, color: 'red')  // normal Kernel IR
```

### Pipeline

| Layer | File | What Changed |
|-------|------|-------------|
| Experiment flag | `tools/experimental_features.yaml` | `record-spreads` flag (disabled by default) |
| Parser | `pkg/_fe_analyzer_shared/lib/src/parser/parser_impl.dart` | Detects `...`/`...?` in record context, calls `handleRecordSpreadField` |
| Listener | `pkg/_fe_analyzer_shared/lib/src/parser/listener.dart` | New `handleRecordSpreadField(Token)` event |
| Forwarding listener | `pkg/_fe_analyzer_shared/lib/src/parser/forwarding_listener.dart` | Forwards the event |
| CFE internal AST | `pkg/front_end/lib/src/kernel/internal_ast.dart` | `RecordSpreadElement` class (marker node, never in output IR) |
| CFE body builder | `pkg/front_end/lib/src/kernel/body_builder.dart` | `handleRecordSpreadField()` + `endRecordLiteral()` spread handling |
| CFE type inference | `pkg/front_end/lib/src/type_inference/inference_visitor.dart` | `_expandRecordSpreads()` — **the core desugaring** |
| CFE diagnostics | `pkg/front_end/messages.yaml` | 4 error messages defined |
| CFE const eval | `pkg/front_end/lib/src/kernel/constant_evaluator.dart` | Removed `enableConstFunctions` guard so `RecordIndexGet`/`RecordNameGet` work in const |
| Analyzer AST | `pkg/analyzer/lib/src/dart/ast/ast.dart` | `RecordSpreadField` interface + `RecordSpreadFieldImpl` |
| Analyzer builder | `pkg/analyzer/lib/src/fasta/ast_builder.dart` | `handleRecordSpreadField()` |
| Analyzer resolver | `pkg/analyzer/lib/src/dart/resolver/record_literal_resolver.dart` | Spread field resolution + type expansion |
| Analyzer diagnostics | `pkg/analyzer/messages.yaml` | 3 error messages defined |
| Value kinds | `pkg/front_end/lib/src/source/value_kinds.dart` | `ValueKinds.RecordSpreadElement` for stack checking |

### Usage Examples

Enable with `--enable-experiment=record-spreads`.

**Extend a record with extra fields:**
```dart
var point = (1, 2);
var colorPoint = (...point, color: 'red');
// colorPoint is (int, int, {String color})
// colorPoint.$1 == 1, colorPoint.$2 == 2, colorPoint.color == 'red'
```

**Merge named records:**
```dart
var coords = (x: 10, y: 20);
var style = (color: 'blue');
var styled = (...coords, ...style);
// styled is ({int x, int y, String color})
```

**Multiple positional spreads:**
```dart
var a = (1, 2);
var b = (3, 4);
var quad = (...a, ...b);  // (int, int, int, int)
```

**Const spreading:**
```dart
const base = (1, 2);
const triple = (...base, 3);  // const (1, 2, 3)
const viaSpread = (...base);
identical(base, viaSpread);   // true — canonicalized
```

**Ternary + null-coalescing (handle nullable records explicitly):**
```dart
(int, int)? maybePoint = null;
var safe = (...(maybePoint ?? (0, 0)), color: 'red');
```

**Pattern matching on spread results:**
```dart
var coords = (x: 10, y: 20);
var point3d = (...coords, z: 30);
var (x: px, y: py, z: pz) = point3d;  // destructure
```

**Evaluation order guarantee — spread evaluated exactly once:**
```dart
int callCount = 0;
(int, int) makePoint() { callCount++; return (1, 2); }
var result = (...makePoint(), 3);
assert(callCount == 1);  // single evaluation, hoisted to temp variable
```

---

## Test Coverage

**Location:** `tests/language/record_spreads/`

All tests use `// SharedOptions=--enable-experiment=record-spreads`.

| Test File | What It Covers | Cases |
|-----------|---------------|-------|
| `record_spread_basic_test.dart` | Core spreading: positional, named, mixed, multiple spreads, single-element, nested | 11 test scenarios |
| `record_spread_const_test.dart` | Const spreading, const identity (`identical`), const + named fields | 5 test scenarios |
| `record_spread_error_test.dart` | Compile errors: non-record types (`int`, `String`, `List`), `dynamic`, abstract `Record`, generic `T extends Record`, `...?`, duplicate names, `$N` clash | 10 error cases |
| `record_spread_evaluation_order_test.dart` | Single evaluation guarantee, left-to-right ordering, interleaved spread + non-spread | 4 test scenarios |
| `record_spread_inference_test.dart` | Static type checking, named type preservation, downward inference (`(num,num) = ...intPair`), subtyping | 7 type assertions |
| `record_spread_mixed_syntax_test.dart` | Collections, pattern matching, functions/closures, conditionals, async/await, string interpolation, type tests, loops, nested records, classes, typedefs, switch guards, try/catch, const vs runtime | 16 test groups, ~100 assertions |

---

## Issue Coverage Matrix

| Issue Requirement | Status | Notes |
|-------------------|--------|-------|
| `...record` in record literals | **Done** | Full desugaring in `_expandRecordSpreads()` |
| Concrete record type required | **Done** | `RecordType` check; errors for `dynamic`, `Record`, generics |
| No `Destructure_N_` interfaces | **N/A** | Correctly omitted per @lrhn's rejection |
| No `if`/`for` in records | **N/A** | Correctly omitted per @lrhn's rejection |
| No dynamic record operations | **Done** | Spread of `dynamic`/`Record`/`T extends Record` → error |
| `...record` in argument lists | **Deferred** | Planned for Round 2 (Steps 3, 5c, 6c-d, 9) |
| Const evaluation | **Done** | `RecordIndexGet`/`RecordNameGet` enabled for const; tests pass |
| Null-aware `...?` rejection | **Message defined** | Error message exists but **not emitted** in CFE (Gap 2) |
| Evaluation order (single eval) | **Done** | Hoisting via `VariableDeclaration` + `BlockExpression` |
| Experiment flag gating | **Partial** | Flag exists but `reportIfNotEnabled` is a TODO (Gap 1) |

---

## Known Gaps

7 gaps documented in [RecordSpreadingImplementationPlan.md](RecordSpreadingImplementationPlan.md#gaps-plan-vs-issue-2128):

| # | Gap | Severity |
|---|-----|----------|
| 1 | `reportIfNotEnabled` experiment flag guard is a TODO | **MUST FIX** |
| 2 | `...?` null-aware error never emitted in CFE | **MUST FIX** |
| 3 | `$N` positional name clash check defined but never emitted | SHOULD FIX |
| 4 | Analyzer errors are placeholder TODOs (5 instances) | SHOULD FIX |
| 5 | No `visitRecordSpreadField` in AstVisitor (delegates to inner expression) | SHOULD FIX |
| 6 | Argument list spreading deferred to Round 2 | KNOWN |
| 7 | Forbidden/private name validation incomplete for spread-contributed fields in CFE | SHOULD FIX |

**Gap 7 note:** Low practical risk — a record with forbidden named fields (e.g., `hashCode`, `_private`) would have been rejected when that record was originally created. The check is defense-in-depth.

---

## What's NOT in Scope (Confirmed by Issue Discussion)

- **Argument list spreading** — deferred to Round 2, per plan. @munificent strongly supports this.
- **`Destructure_N_` interfaces** — rejected by @lrhn, not implemented.
- **Spreading record typedefs in parameter lists** — @ds84182's suggestion; not part of #2128 core.
- **Dynamic record operations** — rejected by @lrhn for implementation/performance reasons.
- **`if`/`for` in record literals** — rejected by @lrhn; only makes sense for arbitrary-length sequences.
- **Formatter support** — `dart_style` is a separate package; deferred.
