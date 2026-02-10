# Record Spreading Implementation Plan

## Context

**Issue:** [dart-lang/language#2128](https://github.com/dart-lang/language/issues/2128)

Dart records currently have no spread operator. This feature adds `...recordExpression` inside record literals (and eventually argument lists), inlining all fields of the record at the spread point:

```dart
(num, num) point = (1, 2);
(num, num, {Color color}) colorPoint = (...point, color: Color.red);
// Equivalent to: (point.$1, point.$2, color: Color.red)
```

**Key constraint:** This is a **purely static** operation. The spread expression must have a concrete record type (not `dynamic`, `Record`, or `T extends Record`). Because the type is known at compile time, the spread can be fully desugared during type inference. **No backend changes are needed** — dart2js, DDC, dart2wasm, and the VM all see a normal `RecordLiteral` after desugaring.

**Scope (first round):** Record literal spreading only. Argument list spreading is deferred to a follow-up round. Steps marked with **[DEFERRED]** are kept for reference but skipped in the initial implementation.

---

## Step 1: Experiment Flag

Add `record-spreads` to [tools/experimental_features.yaml](tools/experimental_features.yaml) (after line 159):

```yaml
  record-spreads:
    help: "Allow spreading record values into record literals and argument lists."
```

No `enabledIn` — keeps it disabled by default behind `--enable-experiment=record-spreads`.

Then run the code generation commands (lines 18-34 of that file):

```bash
dart pkg/analyzer/tool/experiments/generate.dart
dart pkg/analyzer/tool/api/generate.dart
# Bump DATA_VERSION in pkg/analyzer/lib/src/dart/analysis/driver.dart
# Update pkg/analyzer_testing/lib/experiments/experiments.dart
dart pkg/front_end/tool/cfe.dart generate-experimental-flags
dart pkg/front_end/tool/update_expectations.dart
dart tools/generate_experimental_flags.dart
```

This generates `ExperimentalFlag.recordSpreads` in:
- `pkg/_fe_analyzer_shared/lib/src/experiments/flags.dart`
- The CFE `LibraryFeatures` class
- The analyzer experimental features

---

## Step 2: Parser — Record Literal Spread

**File:** [pkg/_fe_analyzer_shared/lib/src/parser/parser_impl.dart](pkg/_fe_analyzer_shared/lib/src/parser/parser_impl.dart)

**Method:** `parseParenthesizedExpressionOrRecordLiteral()` (line 7978)

The current loop at line 7995 checks for:
1. Close paren → end
2. Named field (`identifier:`) → `handleNamedRecordField`
3. Positional expression → `handlePositionalRecordField`

**Change:** Before the named-field check at line 8010, add spread detection:

```dart
// After line 8009 (the break for illegal trailing comma)
// and before line 8010 (the colon check):

Token next = token.next!;
// ... existing close-paren check ...

// NEW: Check for spread operator
if (next.isA(TokenType.PERIOD_PERIOD_PERIOD) ||
    next.isA(TokenType.PERIOD_PERIOD_PERIOD_QUESTION)) {
  Token spreadOperator = next;
  wasRecord = true;
  wasValidRecord = true;
  token = parseExpression(next);  // Parse the spread operand
  listener.handleRecordSpreadField(spreadOperator);
  ++count;
  // Fall through to comma check at line 8031
  next = token.next!;
  if (!next.isA(TokenType.COMMA)) {
    break;
  }
  token = next;
  continue;
}

// Existing named field check continues here...
Token? colon = null;
if (next.next!.isA(TokenType.COLON) || ...
```

When `...` is seen in record context, it forces `wasRecord = true` (a spread cannot appear in a parenthesized expression). The expression after `...` is parsed, then `handleRecordSpreadField(spreadToken)` is called.

---

## Step 3: Parser — Argument List Spread **[DEFERRED — second round]**

**File:** [pkg/_fe_analyzer_shared/lib/src/parser/parser_impl.dart](pkg/_fe_analyzer_shared/lib/src/parser/parser_impl.dart)

**Method:** `parseArgumentsRest()` (line 9232)

The current loop at line 9239 checks for named arguments (`identifier:`) and positional arguments. There's also a shortcut optimization block (line 9260) for common cases.

**Change:** Before the colon check at line 9245, add spread detection:

```dart
Token next = token.next!;
if (next.isA(TokenType.CLOSE_PAREN)) { ... }  // existing

// NEW: Check for spread in argument list
if (next.isA(TokenType.PERIOD_PERIOD_PERIOD) ||
    next.isA(TokenType.PERIOD_PERIOD_PERIOD_QUESTION)) {
  Token spreadOperator = next;
  token = parseExpression(next);
  listener.handleArgumentSpread(spreadOperator);
  ++argumentCount;
  next = token.next!;
  if (!next.isA(TokenType.COMMA)) {
    break;
  }
  token = next;
  continue;
}

// Existing colon check continues here...
Token? colon = null;
```

---

## Step 4: Listener Events

### 4a. Base Listener

**File:** [pkg/_fe_analyzer_shared/lib/src/parser/listener.dart](pkg/_fe_analyzer_shared/lib/src/parser/listener.dart) (near line 2043)

Add new method (plus `handleArgumentSpread` **[DEFERRED]**):

```dart
/// Called after parsing a spread expression (`...expr` or `...?expr`)
/// as a field in a record literal.
///
/// Substructures:
/// - expression (the spread operand, on top of the stack)
void handleRecordSpreadField(Token spreadToken) {
  logEvent("RecordSpreadField");
}

/// [DEFERRED — second round]
/// Called after parsing a spread expression (`...expr` or `...?expr`)
/// as an argument in a function argument list.
///
/// Substructures:
/// - expression (the spread operand, on top of the stack)
void handleArgumentSpread(Token spreadToken) {
  logEvent("ArgumentSpread");
}
```

### 4b. Forwarding Listener

**File:** [pkg/_fe_analyzer_shared/lib/src/parser/forwarding_listener.dart](pkg/_fe_analyzer_shared/lib/src/parser/forwarding_listener.dart) (near line 1933)

Add:

```dart
@override
void handleRecordSpreadField(Token spreadToken) {
  listener?.handleRecordSpreadField(spreadToken);
}

@override
void handleArgumentSpread(Token spreadToken) {
  listener?.handleArgumentSpread(spreadToken);
}
```

---

## Step 5: Internal AST Nodes (CFE)

**File:** [pkg/front_end/lib/src/kernel/internal_ast.dart](pkg/front_end/lib/src/kernel/internal_ast.dart)

### 5a. `RecordSpreadElement` (new class, near line 5058)

A lightweight marker that exists **only** between parsing and type inference. Not a kernel `Expression` — it never appears in the output Kernel IR.

```dart
/// A spread element within a record literal: `...expr` or `...?expr`.
///
/// This exists only during parsing → type inference. During type inference,
/// the spread is expanded into individual RecordIndexGet/RecordNameGet
/// field accesses based on the static type of [expression].
class RecordSpreadElement {
  Expression expression;
  final bool isNullAware;
  final int fileOffset;

  RecordSpreadElement(
    this.expression, {
    required this.isNullAware,
    required this.fileOffset,
  });
}
```

### 5b. Update `InternalRecordLiteral` comment (line 5010)

Change the type comment on `originalElementOrder`:

```dart
// Before:
final List<Object /*Expression|NamedExpression*/> originalElementOrder;

// After:
final List<Object /*Expression|NamedExpression|RecordSpreadElement*/> originalElementOrder;
```

### 5c. `SpreadArgument` (new class, after `SuperNamedArgument` at line 356) **[DEFERRED — second round]**

Since `Argument` is `sealed` (line 290), the compiler will enforce exhaustive handling everywhere `Argument` is switched on.

```dart
/// A spread argument in a function call: `...expr` or `...?expr`.
///
/// During type inference, this is expanded into individual
/// PositionalArgument and NamedArgument entries based on the
/// static record type of [expression].
class SpreadArgument extends Argument {
  @override
  Expression expression;
  final bool isNullAware;

  SpreadArgument(this.expression, {required this.isNullAware});

  @override
  TreeNode get node => expression;

  @override
  void toTextInternal(AstPrinter printer) {
    printer.write('...');
    if (isNullAware) printer.write('?');
    expression.toTextInternal(printer);
  }

  @override
  String toString() => 'SpreadArgument($expression)';
}
```

### 5d. Update `ValueKinds` for stack type checking

**File:** [pkg/front_end/lib/src/kernel/body_builder.dart](pkg/front_end/lib/src/kernel/body_builder.dart)

Add `RecordSpreadElement` to the union in `endRecordLiteral()`'s `checkState` (line 4298):

```dart
// Before:
unionOfKinds([
  ValueKinds.Expression,
  ValueKinds.NamedExpression,
  ValueKinds.ParserRecovery,
]),

// After:
unionOfKinds([
  ValueKinds.Expression,
  ValueKinds.NamedExpression,
  ValueKinds.RecordSpreadElement,  // NEW
  ValueKinds.ParserRecovery,
]),
```

Also add `ValueKinds.RecordSpreadElement` and `ValueKinds.SpreadArgument` to the `ValueKinds` class. The `ValueKinds` class is likely in a shared file — find it and add the new kinds.

---

## Step 6: Body Builder — Record Spread Handling

**File:** [pkg/front_end/lib/src/kernel/body_builder.dart](pkg/front_end/lib/src/kernel/body_builder.dart)

### 6a. New `handleRecordSpreadField()` (near line 7674)

```dart
@override
void handleRecordSpreadField(Token spreadToken) {
  debugEvent("RecordSpreadField");
  reportIfNotEnabled(
    libraryFeatures.recordSpreads,
    spreadToken.charOffset,
    spreadToken.charCount,
  );
  Expression value = popForValue();
  push(RecordSpreadElement(
    value,
    isNullAware: spreadToken.lexeme == '...?',
    fileOffset: spreadToken.charOffset,
  ));
}
```

### 6b. Modify `endRecordLiteral()` (line 4334)

The existing loop at line 4334 checks `element is NamedExpression` vs positional `Expression`. Add handling for `RecordSpreadElement`:

```dart
for (Object? element in elements) {
  // NEW: Handle spread elements
  if (element is RecordSpreadElement) {
    // Don't add to positional or named — that happens during type inference
    // when we know the spread's record type.
    originalElementOrder.add(element);
    continue;
  }

  if (element is NamedExpression) {
    // ... existing named handling (lines 4336-4376) ...
  } else {
    // ... existing positional handling (lines 4377-4381) ...
  }
}
```

**Important:** The duplicate name checks (line 4353) and `$N` name clash checks (line 4385) cannot be fully performed for spread elements at this stage (we don't know their fields yet). These must be **deferred to type inference** in Step 8.

### 6c. New `handleArgumentSpread()` (near line 7635) **[DEFERRED — second round]**

```dart
@override
void handleArgumentSpread(Token spreadToken) {
  debugEvent("ArgumentSpread");
  reportIfNotEnabled(
    libraryFeatures.recordSpreads,
    spreadToken.charOffset,
    spreadToken.charCount,
  );
  Expression value = popForValue();
  push(SpreadArgument(
    value,
    isNullAware: spreadToken.lexeme == '...?',
  ));
}
```

### 6d. Modify `endArguments()` (line 1357) **[DEFERRED — second round]**

The existing `switch` at line 1359 only handles `NamedArgument` and `PositionalArgument`. Since `Argument` is `sealed`, adding `SpreadArgument` **will produce a compile error** until we add the case:

```dart
for (int i = 0; i < arguments.length; i++) {
  Argument argument = arguments[i];
  switch (argument) {
    case NamedArgument():
      firstNamedArgumentIndex = i < firstNamedArgumentIndex
          ? i : firstNamedArgumentIndex;
    case PositionalArgument():
      positionalCount++;
      if (i > firstNamedArgumentIndex) {
        hasNamedBeforePositional = true;
        // ... existing check ...
      }
    case SpreadArgument():                           // NEW
      // Count as 0 positionals for now; actual expansion
      // happens during type inference when we know the record type.
      // Don't adjust positionalCount or firstNamedArgumentIndex.
      break;
  }
}
```

---

## Step 7: Error Messages

**File:** [pkg/front_end/messages.yaml](pkg/front_end/messages.yaml)

Add new diagnostic messages:

```yaml
RecordSpreadNotRecordType:
  problemMessage: "A spread expression in a record literal must have a record type, but has type '#type'."
  correctionMessage: "Try using an expression with a concrete record type."
  analyzerCode: RECORD_SPREAD_NOT_RECORD_TYPE

RecordSpreadDuplicateNamedField:
  problemMessage: "The named field '#name' from the spread conflicts with another field with the same name."
  analyzerCode: RECORD_SPREAD_DUPLICATE_NAMED_FIELD

RecordSpreadNullAwareNotSupported:
  problemMessage: "Null-aware spread '...?' is not supported in record literals or argument lists."
  correctionMessage: "Handle null before spreading, or use a non-nullable expression."
  analyzerCode: RECORD_SPREAD_NULL_AWARE_NOT_SUPPORTED

# [DEFERRED — second round]
ArgumentSpreadNotRecordType:
  problemMessage: "A spread expression in an argument list must have a record type, but has type '#type'."
  correctionMessage: "Try using an expression with a concrete record type."
  analyzerCode: ARGUMENT_SPREAD_NOT_RECORD_TYPE

RecordSpreadPositionalNameClash:
  problemMessage: "The named field '#name' from the spread clashes with a positional field getter."
  analyzerCode: RECORD_SPREAD_POSITIONAL_NAME_CLASH
```

After adding messages, run:
```bash
dart pkg/front_end/tool/cfe.dart generate-messages
```

---

## Step 8: Type Inference Desugaring — Record Literals (THE CORE)

**File:** [pkg/front_end/lib/src/type_inference/inference_visitor.dart](pkg/front_end/lib/src/type_inference/inference_visitor.dart)

**Method:** `visitInternalRecordLiteral()` (line 14031)

This is the heart of the implementation. Currently, the method iterates `originalElementOrder` and handles `NamedExpression` (lines 14108-14129) and positional `Expression` (lines 14130-14153).

### 8a. Pre-expansion pass

Add a new pre-processing step **before** the main inference loop (before line 14042). This pass resolves spread elements and expands them:

```dart
ExpressionInferenceResult visitInternalRecordLiteral(
  InternalRecordLiteral node,
  DartType typeContext,
) {
  List<Expression> positional = node.positional;
  List<NamedExpression> namedUnsorted = node.named;
  // ... existing declarations ...

  // === NEW: Expand record spread elements ===
  _expandRecordSpreads(node);
  // After expansion, node.positional and node.named are updated,
  // node.originalElementOrder contains only Expression and NamedExpression,
  // and all RecordSpreadElement entries have been replaced.
  positional = node.positional;
  namedUnsorted = node.named;

  // ... rest of existing code unchanged ...
```

### 8b. `_expandRecordSpreads()` helper method

Add this as a method on `InferenceVisitorImpl`:

```dart
void _expandRecordSpreads(InternalRecordLiteral node) {
  List<Object> originalOrder = node.originalElementOrder;
  bool hasSpread = false;
  for (Object element in originalOrder) {
    if (element is RecordSpreadElement) {
      hasSpread = true;
      break;
    }
  }
  if (!hasSpread) return;  // Fast path: no spreads, nothing to do

  List<Expression> newPositional = [];
  List<NamedExpression> newNamed = [];
  List<Object> newOriginalOrder = [];
  Map<String, NamedExpression> newNamedElements = {};

  for (Object element in originalOrder) {
    if (element is RecordSpreadElement) {
      // 1. Report error if null-aware
      if (element.isNullAware) {
        // Report: null-aware spread not supported in records
        // Push an InvalidExpression and continue
      }

      // 2. Infer the type of the spread expression
      ExpressionInferenceResult spreadResult = inferExpression(
        element.expression,
        const UnknownType(),
      );
      Expression spreadExpr = spreadResult.expression;
      DartType spreadType = spreadResult.inferredType;

      // 3. Validate: must be a concrete record type
      if (spreadType is! RecordType) {
        // Report error: spread must have a record type
        // Create InvalidExpression, push as a single positional field
        continue;
      }
      RecordType recordType = spreadType;

      // 4. Hoist to temp variable if >1 field (avoid re-evaluation)
      VariableDeclaration? temp;
      if (recordType.positional.length + recordType.named.length > 1) {
        temp = createVariable(spreadExpr, recordType);
        // The temp will be wrapped in a BlockExpression later
      }

      Expression getReceiver() {
        if (temp != null) {
          return createVariableGet(temp);
        }
        return spreadExpr;  // Only safe if single field
      }

      // 5. Expand positional fields
      for (int i = 0; i < recordType.positional.length; i++) {
        Expression fieldAccess = RecordIndexGet(
          getReceiver(),
          recordType,
          i,
        )..fileOffset = element.fileOffset;
        newPositional.add(fieldAccess);
        newOriginalOrder.add(fieldAccess);
      }

      // 6. Expand named fields
      for (NamedType namedType in recordType.named) {
        Expression fieldAccess = RecordNameGet(
          getReceiver(),
          recordType,
          namedType.name,
        )..fileOffset = element.fileOffset;
        NamedExpression namedExpr = NamedExpression(
          namedType.name,
          fieldAccess,
        )..fileOffset = element.fileOffset;

        // Check for duplicate named fields
        if (newNamedElements.containsKey(namedType.name)) {
          // Report error: duplicate named field
        } else {
          newNamed.add(namedExpr);
          newNamedElements[namedType.name] = namedExpr;
          newOriginalOrder.add(namedExpr);
        }
      }

      // 7. If hoisted, wrap the entire record literal later
      // Store the temp variable for BlockExpression wrapping

    } else if (element is NamedExpression) {
      if (newNamedElements.containsKey(element.name)) {
        // Report error: duplicate named field from spread + explicit
      } else {
        newNamed.add(element);
        newNamedElements[element.name] = element;
        newOriginalOrder.add(element);
      }
    } else {
      Expression expr = element as Expression;
      newPositional.add(expr);
      newOriginalOrder.add(expr);
    }
  }

  // Replace the node's lists in-place
  node.positional
    ..clear()
    ..addAll(newPositional);
  node.named
    ..clear()
    ..addAll(newNamed);
  node.originalElementOrder
    ..clear()
    ..addAll(newOriginalOrder);
  // Update namedElements map
  // node.namedElements is final, so we need to handle this carefully
  // (may need to make it non-final or use a different mechanism)
}
```

### 8c. Hoisting with temp variables

When a spread has >1 field, the spread expression must be evaluated **exactly once**. We hoist it into a `VariableDeclaration`:

```dart
// Spread: ...point  where point: (int, int)
// Desugars to:
//   let tmp = point in (tmp.$1, tmp.$2, color: Color.red)
```

The existing hoisting mechanism (lines 14167-14221) wraps in `VariableDeclaration` and builds a `BlockExpression` at the end (line 14261-14273). We can reuse this pattern.

For **const** records (line 14167: `!node.isConst`), hoisting is disabled because const expressions have no side effects. A const spread expression like `const (...constRecord, x: 1)` just directly generates `RecordIndexGet(constRecord, ...)` without a temp variable.

### 8d. Context type handling

The context type matching at line 14044 currently checks `typeContext.positional.length == positional.length`. After spread expansion, `positional.length` will be correct (spread fields already expanded). This means context matching **just works** after the expansion pass — no changes needed to the context logic.

### 8e. Validation checks deferred from body builder

After expansion, perform the checks that were deferred from `endRecordLiteral()`:
- Named field names don't clash with Object members (`hashCode`, `toString`, etc.)
- Named field names don't start with `_`
- Named fields don't clash with positional field getters (`$1`, `$2`, etc.)
- No duplicate named field names across spreads and explicit fields

---

## Step 9: Type Inference Desugaring — Argument Lists **[DEFERRED — second round]**

**File:** [pkg/front_end/lib/src/type_inference/inference_visitor_base.dart](pkg/front_end/lib/src/type_inference/inference_visitor_base.dart)

The argument list inference happens in `_inferInvocation()`. When we encounter a `SpreadArgument`, we need to expand it **before** formal parameter matching.

### 9a. Add pre-processing method

Add `_expandSpreadArguments()` as a method on the inference visitor:

```dart
void _expandSpreadArguments(ActualArguments actualArguments) {
  List<Argument> arguments = actualArguments.argumentList;
  bool hasSpread = arguments.any((a) => a is SpreadArgument);
  if (!hasSpread) return;

  List<Argument> expanded = [];
  for (Argument arg in arguments) {
    if (arg is SpreadArgument) {
      // 1. Report error if null-aware
      if (arg.isNullAware) {
        // Report error
        continue;
      }

      // 2. Infer spread expression type
      ExpressionInferenceResult result = inferExpression(
        arg.expression, const UnknownType());
      DartType type = result.inferredType;

      // 3. Validate it's a concrete record type
      if (type is! RecordType) {
        // Report error
        continue;
      }

      // 4. Hoist to temp variable
      Expression spreadExpr = result.expression;
      VariableDeclaration? temp;
      if (type.positional.length + type.named.length > 1) {
        temp = createVariable(spreadExpr, type);
      }

      // 5. Expand positional fields
      for (int i = 0; i < type.positional.length; i++) {
        Expression fieldAccess = RecordIndexGet(
          temp != null ? createVariableGet(temp) : spreadExpr,
          type, i,
        );
        expanded.add(PositionalArgument(fieldAccess));
      }

      // 6. Expand named fields
      for (NamedType namedType in type.named) {
        Expression fieldAccess = RecordNameGet(
          temp != null ? createVariableGet(temp) : spreadExpr,
          type, namedType.name,
        );
        expanded.add(NamedArgument(
          NamedExpression(namedType.name, fieldAccess),
        ));
      }
    } else {
      expanded.add(arg);
    }
  }

  // Replace the argument list and update counts
  actualArguments.replaceArguments(expanded);
}
```

### 9b. Call the expansion before inference

In `_inferInvocation()`, call `_expandSpreadArguments(actualArguments)` early, before formal parameter matching begins. After expansion, all arguments are normal `PositionalArgument` or `NamedArgument` and the rest of inference proceeds unchanged.

---

## Step 10: Analyzer Implementation (Parallel Path)

The analyzer has its own AST and resolution pipeline, separate from the CFE.

### 10a. New AST node

**File:** [pkg/analyzer/lib/src/dart/ast/ast.dart](pkg/analyzer/lib/src/dart/ast/ast.dart)

Add `RecordSpreadFieldImpl` (near `RecordLiteralImpl` at line 23671):

```dart
/// A spread expression as a field in a record literal: `...expr`.
final class RecordSpreadFieldImpl extends ExpressionImpl
    implements RecordSpreadField {
  @override
  final Token spreadOperator;

  ExpressionImpl _expression;

  RecordSpreadFieldImpl({
    required this.spreadOperator,
    required ExpressionImpl expression,
  }) : _expression = expression {
    _becomeParentOf(_expression);
  }

  @override
  ExpressionImpl get expression => _expression;

  set expression(ExpressionImpl expression) {
    _expression = _becomeParentOf(expression);
  }

  bool get isNullAware =>
      spreadOperator.type == TokenType.PERIOD_PERIOD_PERIOD_QUESTION;

  @override
  Token get beginToken => spreadOperator;

  @override
  Token get endToken => _expression.endToken;

  // ... visitor accept methods, childEntities, etc.
}
```

### 10b. Analyzer AST Builder

**File:** [pkg/analyzer/lib/src/fasta/ast_builder.dart](pkg/analyzer/lib/src/fasta/ast_builder.dart)

Currently `handleNamedRecordField` delegates to `handleNamedArgument` (line 4989). Add:

```dart
@override
void handleRecordSpreadField(Token spreadToken) {
  var expression = pop() as ExpressionImpl;
  push(RecordSpreadFieldImpl(
    spreadOperator: spreadToken,
    expression: expression,
  ));
}

@override
void handleArgumentSpread(Token spreadToken) {
  var expression = pop() as ExpressionImpl;
  // For argument lists, reuse SpreadElementImpl or create a similar node
  push(SpreadElementImpl(
    spreadOperator: spreadToken,
    expression: expression,
  ));
}
```

### 10c. Record Literal Resolver

**File:** [pkg/analyzer/lib/src/dart/resolver/record_literal_resolver.dart](pkg/analyzer/lib/src/dart/resolver/record_literal_resolver.dart)

Modify `_resolveFields()` (line 160) to handle `RecordSpreadFieldImpl`:

```dart
void _resolveFields(RecordLiteralImpl node, DartType contextType) {
  var positionalFields = <RecordTypePositionalFieldImpl>[];
  var namedFields = <RecordTypeNamedFieldImpl>[];
  // Context matching needs to account for spreads...

  var index = 0;
  for (var field in node.fields) {
    if (field is RecordSpreadFieldImpl) {
      // 1. Resolve the spread expression
      var spreadType = _resolveField(field.expression, UnknownInferredType.instance);

      // 2. Validate it's a concrete RecordType
      if (spreadType is! RecordTypeImpl) {
        // Report error
        continue;
      }

      // 3. Expand positional fields into the result type
      for (var posField in spreadType.positionalFields) {
        positionalFields.add(RecordTypePositionalFieldImpl(type: posField.type));
      }

      // 4. Expand named fields into the result type
      for (var namedField in spreadType.namedFields) {
        namedFields.add(RecordTypeNamedFieldImpl(
          name: namedField.name,
          type: namedField.type,
        ));
      }
    } else if (field is NamedExpressionImpl) {
      // ... existing named handling (lines 166-176) ...
    } else {
      // ... existing positional handling (lines 177-186) ...
    }
  }

  node.recordStaticType(
    RecordTypeImpl(
      positionalFields: positionalFields,
      namedFields: namedFields,
      nullabilitySuffix: NullabilitySuffix.none,
    ),
    resolver: _resolver,
  );
}
```

Also update `_matchContextType()` (line 40) and `_reportDuplicateFieldDefinitions()` (line 79) and `_reportInvalidFieldNames()` (line 101) to handle `RecordSpreadFieldImpl`.

---

## Step 11: Const Evaluation

**No direct changes needed.**

Since desugaring happens during type inference (Step 8), by the time the constant evaluator sees the `RecordLiteral`, it's a normal `RecordLiteral` with `RecordIndexGet`/`RecordNameGet` as field expressions. The constant evaluator already handles:

- `RecordIndexGet` at [pkg/front_end/lib/src/kernel/constant_evaluator.dart](pkg/front_end/lib/src/kernel/constant_evaluator.dart) (~line 4680)
- `RecordNameGet` (~line 4700)

For const records, hoisting is disabled (`!node.isConst` at line 14167), so `RecordIndexGet(constExpr, ...)` evaluates directly to the constant field value.

Verify with tests:
```dart
const point = (1, 2);
const colorPoint = (...point, color: 'red');
// Should work: desugars to const (point.$1, point.$2, color: 'red')
// Which const-evaluates to (1, 2, color: 'red')
```

---

## Step 12: Null-Aware Spread Decision

**Recommendation: Do NOT support `...?` for record spreads.** Report an error.

**Rationale:** Unlike collection spreads where `...?nullableList` can conditionally add 0 or N elements, record fields are structurally fixed at compile time. You cannot conditionally include/exclude fields from a record type. The resulting record type must be statically known.

If the user has a nullable record, they should handle it explicitly:
```dart
(int, int)? maybePoint = ...;
var result = (...(maybePoint ?? (0, 0)), color: 'red');
```

---

## Step 13: Tests

Create test files in `tests/language/record_spreads/`:

### 13a. Basic Tests (`record_spread_basic_test.dart`)
- Spread positional-only record: `(...(1, 2), 3)` → `(int, int, int)`
- Spread named-only record: `(...(a: 1, b: 2))` → `({int a, int b})`
- Spread mixed record: `(...(1, a: 2))` → `(int, {int a})`
- Spread with additional fields: `(...(1, 2), color: 'red')` → `(int, int, {String color})`
- Multiple spreads: `(...(1, 2), ...(3, 4))` → `(int, int, int, int)`

### 13b. Argument List Tests (`record_spread_arguments_test.dart`) **[DEFERRED — second round]**
- Spread into function call positional args
- Spread into function call named args
- Spread into constructor call
- Spread into method call

### 13c. Const Tests (`record_spread_const_test.dart`)
- `const (...(1, 2), color: 'red')`
- `const (...constRecord)` where `constRecord` is a const variable

### 13d. Type Inference Tests (`record_spread_inference_test.dart`)
- Downward inference: `(num, num) result = (...intPair)`
- Spread preserves types
- Type context flows through

### 13e. Error Tests (`record_spread_error_test.dart`)
- Spread non-record type → error
- Spread `dynamic` → error
- Spread `Record` (abstract) → error
- Spread `T extends Record` → error
- Null-aware spread `...?` → error
- Duplicate named field from spread + explicit → error
- Named field from spread clashes with positional getter → error
- Named field from spread is forbidden name → error

### 13f. Evaluation Order Tests (`record_spread_evaluation_order_test.dart`)
- Verify spread expression evaluated exactly once
- Verify evaluation order preserved with hoisting

---

## Step 14: Additional Files That Need Updates

These are files that will need minor updates due to the new AST nodes and parser events:

1. **Parser test expectations** — `pkg/front_end/parser_testcases/` will need new test cases for record spread parsing
2. **`InternalRecordLiteral.toTextInternal()`** (internal_ast.dart line 5039) — handle `RecordSpreadElement` in the `originalElementOrder` loop
3. **All `switch` statements over `sealed class Argument`** — the compiler will flag these; grep for `case PositionalArgument` and `case NamedArgument` to find them all **[DEFERRED — only needed when SpreadArgument is added in second round]**
4. **Formatter** (`dart_style` package) — will need spread-in-record formatting rules, but this is a separate package and can be deferred
5. **`pkg/front_end/lib/src/kernel/forest.dart`** — may need a factory method for `RecordSpreadElement`

---

## Verification

### Build
```bash
./tools/build.py -m release most
```

### Run record spread tests
```bash
./tools/test.py -mrelease --runtime=vm tests/language/record_spreads/
```

### Run existing record tests (regression)
```bash
./tools/test.py -mrelease --runtime=vm language/records/
```

### Run analyzer tests
```bash
dart test pkg/analyzer
```

### Run CFE tests
```bash
dart test pkg/front_end
```

### Run parser tests
```bash
dart pkg/front_end/tool/update_expectations.dart
```

---

## Implementation Order Summary

| # | Step | Files | Effort | Round |
|---|------|-------|--------|-------|
| 1 | Experiment flag | `tools/experimental_features.yaml` + generated | Small | 1st |
| 2 | Parser: record spread | `parser_impl.dart` | Small | 1st |
| 3 | Parser: argument spread | `parser_impl.dart` | Small | **DEFERRED** |
| 4 | Listener events (`handleRecordSpreadField`) | `listener.dart`, `forwarding_listener.dart` | Small | 1st |
| 5a-b | Internal AST: `RecordSpreadElement` | `internal_ast.dart` | Small | 1st |
| 5c | Internal AST: `SpreadArgument` | `internal_ast.dart` | Small | **DEFERRED** |
| 6a-b | Body builder: record spread | `body_builder.dart` | Medium | 1st |
| 6c-d | Body builder: argument spread | `body_builder.dart` | Medium | **DEFERRED** |
| 7 | Error messages | `messages.yaml` + generated | Small | 1st |
| 8 | **Type inference: record spread** | **`inference_visitor.dart`** | **Large** | **1st** |
| 9 | Type inference: argument spread | `inference_visitor_base.dart` | Large | **DEFERRED** |
| 10 | Analyzer implementation | `ast.dart`, `ast_builder.dart`, `record_literal_resolver.dart` | Large | 1st |
| 11 | Const evaluation | Verify only, no changes expected | Small | 1st |
| 12 | Null-aware: error message | Covered by Step 7 | None | 1st |
| 13 | Tests (record literal only) | `tests/language/record_spreads/` | Medium | 1st |
| 14 | Fixup exhaustive switches | Various (compiler-guided) | Small | **DEFERRED** |

**First round:** Steps 1, 2, 4, 5a-b, 6a-b, 7, 8, 10, 11, 12, 13. This gets record literal spreading fully working across CFE and analyzer.

**Second round (deferred):** Steps 3, 5c, 6c-d, 9, 13b, 14. Adds argument list spreading on top of the first round.

---

## Gaps: Plan vs. Issue #2128

*Reviewed 2026-02-10 against [dart-lang/language#2128](https://github.com/dart-lang/language/issues/2128) and all comments.*

### Overall Verdict

The plan **directly and correctly** implements the core proposal from issue #2128. The architecture (static desugaring during type inference, no backend changes, null-aware rejection) precisely matches the design discussed in the issue. However, there are **7 concrete gaps** between what the plan specifies and what the code actually delivers:

### Gap 1: Missing Experiment Flag Guard (MUST FIX)

**Plan says (Step 6a):** `reportIfNotEnabled(libraryFeatures.recordSpreads, ...)` in `handleRecordSpreadField`.

**Code has:** A `TODO(christianfindlay)` comment instead. The feature currently works *without* `--enable-experiment=record-spreads` at the CFE level. The parser parses `...` regardless of the flag, and the body builder doesn't gate it.

**File:** `pkg/front_end/lib/src/kernel/body_builder.dart:7686`

**Risk:** High — users on older SDKs or without the flag could accidentally use the feature.

### Gap 2: Null-Aware `...?` Error Not Emitted in CFE (MUST FIX)

**Plan says (Step 12):** Report `recordSpreadNullAwareNotSupported` error when `...?` is used.

**Code has:** The `_expandRecordSpreads()` method in `inference_visitor.dart` never checks `element.isNullAware`. The message `recordSpreadNullAwareNotSupported` is defined in `messages.yaml` and generated in `diagnostic.g.dart`, but **never emitted** anywhere in the CFE type inference path. A `...?` spread will currently be silently accepted and treated identically to `...`.

**File:** `pkg/front_end/lib/src/type_inference/inference_visitor.dart` — the `_expandRecordSpreads` loop

**Risk:** High — contradicts the issue's design requirement that record shapes be statically known.

### Gap 3: `recordSpreadPositionalNameClash` Never Emitted (SHOULD FIX)

**Plan says (Step 8e):** After expansion, check that named fields from spreads don't clash with positional field getters (`$1`, `$2`, etc.).

**Code has:** The message `recordSpreadPositionalNameClash` is defined in `messages.yaml` and generated, but **never emitted** in either the CFE or the analyzer. If a spread contributes a named field `$1` that clashes with a positional field getter, no error is reported.

**Files:** `inference_visitor.dart`, `record_literal_resolver.dart`

**Risk:** Medium — unlikely in practice but violates the records spec's prohibition on `$N` named fields.

### Gap 4: Analyzer Errors Are Placeholder TODOs (SHOULD FIX)

The analyzer's `record_literal_resolver.dart` has **5 TODO comments** where real error reporting should occur:

1. `TODO(record-spreads): Report RECORD_SPREAD_DUPLICATE_NAMED_FIELD` (line 109)
2. `TODO(record-spreads): Also validate named fields from spreads` — private names, forbidden names, positional clashes (line 156)
3. `TODO(record-spreads): Report RECORD_SPREAD_NULL_AWARE_NOT_ALLOWED` (line 249)
4. `TODO(record-spreads): Report RECORD_SPREAD_NOT_RECORD_TYPE error` (line 255)
5. `TODO(record-spreads): Add visitRecordSpreadField to AstVisitor` in `ast.dart` (line 23862)

The error messages are defined in `pkg/analyzer/messages.yaml` but the resolver methods return early or skip instead of actually emitting them.

**Risk:** Medium — the analyzer will not flag user errors; only the CFE will (and even the CFE is missing some, per Gap 2-3).

### Gap 5: `RecordSpreadFieldImpl.accept()` Delegates Instead of Having Proper Visitor (SHOULD FIX)

**Plan says (Step 10a):** Add proper visitor support.

**Code has:** `RecordSpreadFieldImpl.accept()` delegates to `expression.accept(visitor)` with a TODO. This means AST visitors (linter rules, code fixes, refactorings) won't see the spread node — they'll only see the inner expression. The `@GenerateNodeImpl` annotation won't generate visitor methods until a proper `visitRecordSpreadField` is added to `AstVisitor`.

**File:** `pkg/analyzer/lib/src/dart/ast/ast.dart:23862`

### Gap 6: Argument List Spreading Deferred (KNOWN, PER PLAN)

**Issue says:** "It would also work in argument lists." @munificent emphatically agrees.

**Plan says:** Deferred to Round 2.

This is an acknowledged, deliberate deferral — not a bug. The plan's Round 2 steps (3, 5c, 6c-d, 9) cover this completely. Noted here for completeness since the issue treats argument list spreading as a core part of the proposal.

### Gap 7: Named Field Validation from Spreads Incomplete in CFE (SHOULD FIX)

**Plan says (Step 8e):** After expansion, validate that spread-contributed named fields don't clash with Object members (`hashCode`, `toString`, etc.), don't start with `_`, and don't use the `$N` pattern.

**Code has:** The `_expandRecordSpreads()` method checks for duplicate names across spreads, but does **not** check for:
- Forbidden Object member names (`hashCode`, `runtimeType`, `toString`, `noSuchMethod`, `==`)
- Private names starting with `_`
- The `$N` positional getter pattern (same as Gap 3)

These checks exist in `endRecordLiteral()` for non-spread fields but are bypassed for spread-contributed fields.

**File:** `pkg/front_end/lib/src/type_inference/inference_visitor.dart`

**Risk:** Low in practice — a record type with forbidden named fields would have been rejected when the spread source record was itself created. But for robustness, these checks should still be performed on the expanded result.

---

### Summary Table

| # | Gap | Severity | Status |
|---|-----|----------|--------|
| 1 | Missing `reportIfNotEnabled` experiment flag guard | **MUST FIX** | Code has TODO |
| 2 | `...?` null-aware error not emitted in CFE | **MUST FIX** | Message defined, never used |
| 3 | `$N` positional name clash check missing | SHOULD FIX | Message defined, never used |
| 4 | Analyzer errors are placeholder TODOs (5 instances) | SHOULD FIX | TODOs in code |
| 5 | No `visitRecordSpreadField` in AstVisitor | SHOULD FIX | TODO in code |
| 6 | Argument list spreading deferred | KNOWN | Per plan, Round 2 |
| 7 | Forbidden/private name validation for spread fields in CFE | SHOULD FIX | Not implemented |
