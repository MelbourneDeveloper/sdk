# CFE (Common Front End) Patterns

## File locations

- Body builder: `pkg/front_end/lib/src/kernel/body_builder.dart`
- Type inference: `pkg/front_end/lib/src/type_inference/`
- Messages: `pkg/front_end/messages.yaml`
- Generated diagnostics: `pkg/front_end/lib/src/codes/diagnostic.g.dart`
- Kernel AST: `pkg/kernel/lib/ast.dart`

## Body builder pattern

The body builder transforms parsed tokens into Kernel IR. It implements the parser listener interface.

```dart
// Typical listener callback in BodyBuilder:
@override
void handleMyConstruct(Token keyword, Token semicolon) {
  // 1. Pop child expressions/types from the stack
  Expression value = popForValue();

  // 2. Build Kernel IR
  var result = forest.createMyExpression(
    fileOffset: keyword.charOffset,
    value: value,
  );

  // 3. Push result onto the stack
  push(result);
}
```

Key patterns:
- `popForValue()` — pop expression, ensure it's a value
- `popForEffect()` — pop expression, discard value
- `peek()` — look at top of stack without removing
- `push()` — push onto expression stack
- `forest.create*()` — factory methods for Kernel nodes

## Diagnostic messages

### Adding a new message to messages.yaml

```yaml
MyNewError:
  problemMessage: "Cannot do X with '#name'."
  correctionMessage: "Try doing Y instead."
  parameters:
    String name: The problematic identifier.
  script: |
    main() {
      // example that triggers this error
    }
```

After editing, regenerate:
```bash
./tools/sdks/dart-sdk/bin/dart pkg/front_end/tool/generate_messages.dart
```

### Using diagnostics in code

```dart
import 'package:front_end/src/codes/diagnostic.dart' as diag;

// Simple message (no parameters):
problemReporting.addProblem(
  diag.messageMySimpleError,
  charOffset,
  length,
  fileUri,
);

// Message with parameters:
problemReporting.addProblem(
  diag.templateMyParameterizedError.withArguments(name),
  charOffset,
  length,
  fileUri,
);
```

Key rules:
- Use `problemReporting.addProblem()` or `problemReporting.buildProblem()`
- NOT `helper.buildProblem` — that doesn't exist
- `charOffset` and `length` come from the source token
- `fileUri` identifies the source file

### Message parameter types

| Type | Placeholder | Example |
|------|------------|---------|
| `String` | `#name` | Identifier names |
| `int` | `#count` | Counts |
| `DartType` | `#type` | Type names |
| `Name` | `#name` | Qualified names |
| `Constant` | `#constant` | Constant values |

## Hoisted expressions

When desugaring expressions that need evaluation-order guarantees:

```dart
// hoistedExpressions are in REVERSE source order
// Let wrapping makes last element outermost (evaluated first)
// For spread hoisted vars (forward order): reverse before adding
for (var v in spreadVars.reversed) {
  hoistedExpressions.add(v);
}
```

## Kernel IR basics

The CFE produces Kernel IR (`pkg/kernel/lib/ast.dart`). Key node types:

| Kernel node | Dart concept |
|-------------|-------------|
| `VariableGet` | Variable read |
| `VariableSet` | Variable assignment |
| `PropertyGet` | Property access (`obj.field`) |
| `MethodInvocation` | Method call |
| `ConstructorInvocation` | `new Foo()` |
| `Let` | Temporary variable binding |
| `BlockExpression` | Block with expression value |
| `RecordLiteral` | Record literal `(1, name: 'x')` |

## Type inference

Type inference happens in `pkg/front_end/lib/src/type_inference/`. Key classes:

- `InferenceVisitorImpl` — main inference visitor
- `TypeInferrerImpl` — core type inference logic
- `TypeSchemaEnvironment` — subtype checking and type schema operations

Pattern for inferring a new expression type:
```dart
ExpressionInferenceResult visitMyExpression(
    MyExpression node, DartType typeContext) {
  // 1. Infer child expressions
  var childResult = inferExpression(node.child, typeContext);

  // 2. Compute result type
  var resultType = computeMyType(childResult.inferredType);

  // 3. Return result
  return new ExpressionInferenceResult(resultType, node);
}
```
