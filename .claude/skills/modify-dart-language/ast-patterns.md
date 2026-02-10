# Analyzer AST Patterns

## File locations

- Abstract interfaces: `pkg/analyzer/lib/dart/ast/ast.dart`
- Implementation classes: `pkg/analyzer/lib/src/dart/ast/ast.dart`
- Visitors: `pkg/analyzer/lib/dart/ast/visitor.dart` (+ generated `visitor.g.dart`)
- Node generator: `pkg/analyzer/tool/generate_nodes.dart`

## Adding a new AST node

### Step 1: Abstract interface (in `pkg/analyzer/lib/dart/ast/ast.dart`)

```dart
@AnalyzerPublicApi(message: 'exported by lib/dart/ast/ast.dart')
abstract final class MyNewNode implements Expression {
  /// The token for the keyword.
  Token get keyword;

  /// The child expression.
  Expression get expression;
}
```

Key rules:
- Annotate with `@AnalyzerPublicApi`
- Use `abstract final class`
- Extend appropriate base: `Expression`, `Statement`, `CollectionElement`, etc.
- Document every getter with `///` doc comments

### Step 2: Implementation class (in `pkg/analyzer/lib/src/dart/ast/ast.dart`)

```dart
@GenerateNodeImpl(
  childEntitiesOrder: [
    GenerateNodeProperty('keyword'),
    GenerateNodeProperty('expression'),
  ],
)
final class MyNewNodeImpl extends ExpressionImpl implements MyNewNode {
  @generated
  @override
  final Token keyword;

  @generated
  ExpressionImpl _expression;

  @generated
  MyNewNodeImpl({
    required this.keyword,
    required ExpressionImpl expression,
  }) : _expression = expression {
    _becomeParentOf(expression);
  }

  @generated
  @override
  Token get beginToken => keyword;

  @generated
  @override
  Token get endToken => expression.endToken;

  @generated
  @override
  ExpressionImpl get expression => _expression;

  @generated
  @override
  set expression(ExpressionImpl value) {
    _expression = _becomeParentOf(value);
  }

  @generated
  @override
  E? accept<E>(AstVisitor<E> visitor) => visitor.visitMyNewNode(this);

  @generated
  @override
  void visitChildren(AstVisitor visitor) {
    expression.accept(visitor);
  }

  @override
  ChildEntities get _childEntities => ChildEntities()
    ..addToken('keyword', keyword)
    ..addNode('expression', expression);
}
```

Key rules:
- Annotate with `@GenerateNodeImpl` listing children in source order
- Extend the appropriate sealed impl: `ExpressionImpl`, `StatementImpl`, etc.
- `ExpressionImpl` is `sealed` but extensible within `ast.dart` (same library)
- Call `_becomeParentOf()` in constructor for child nodes
- `beginToken` / `endToken` define the source range
- `_childEntities` lists all tokens and nodes in source order

### Step 3: Regenerate visitors

```bash
./tools/sdks/dart-sdk/bin/dart pkg/analyzer/tool/generate_nodes.dart
```

This generates `visitor.g.dart` with `visitMyNewNode` methods.

## Required overrides for ExpressionImpl subclasses

| Override | Purpose |
|----------|---------|
| `beginToken` | First token of this expression |
| `endToken` | Last token of this expression |
| `precedence` | Operator precedence (for parenthesization) |
| `accept<E>` | Visitor dispatch |
| `visitChildren` | Visit all child nodes |
| `resolveExpression` | Type resolution hook |
| `_childEntities` | Source-order children for utilities |

## Visitor pattern

```dart
// In your visitor implementation:
@override
void visitMyNewNode(MyNewNode node) {
  // Process node
  node.visitChildren(this); // recurse into children
}
```

Visitor types:
- `RecursiveAstVisitor` — visits all nodes depth-first
- `GeneralizingAstVisitor` — visits by generalized node type
- `SimpleAstVisitor` — no default recursion
- `BreadthFirstVisitor` — breadth-first traversal

## Common base classes

| Base class | Used for |
|------------|----------|
| `ExpressionImpl` | Expressions (values) |
| `StatementImpl` | Statements |
| `CollectionElementImpl` | List/set/map elements |
| `TypeAnnotationImpl` | Type annotations |
| `DirectiveImpl` | Import/export directives |
| `DeclarationImpl` | Declarations |
