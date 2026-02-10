# Parser Patterns

## File locations

- Parser: `pkg/_fe_analyzer_shared/lib/src/parser/parser_impl.dart`
- Listener interface: `pkg/_fe_analyzer_shared/lib/src/parser/listener.dart`
- Token types: `pkg/_fe_analyzer_shared/lib/src/scanner/token.dart`
- Keyword definitions: `pkg/_fe_analyzer_shared/lib/src/scanner/token_impl.dart`

## Parser method pattern

```dart
/// ```
/// myConstruct:
///   'keyword' expression ';'
/// ;
/// ```
Token parseMyConstruct(Token token) {
  Token keyword = token.next!;
  assert(keyword.isA(Keyword.MY_KEYWORD));
  listener.beginMyConstruct(keyword);

  token = parseExpression(keyword);

  Token semicolon = ensureSemicolon(token);
  listener.endMyConstruct(keyword, semicolon);
  return semicolon;
}
```

Key rules:
- Document grammar production in `///` comment
- Method takes current `Token`, returns the **last consumed** token
- Call `listener.begin*()` at the start
- Call `listener.end*()` or `listener.handle*()` at the end
- Use `token.next!` to advance (parser doesn't consume tokens itself)
- Use `ensureX()` for required tokens

## Token checking

```dart
// Check next token type
if (token.next!.isA(TokenType.OPEN_PAREN)) { ... }
if (token.next!.isA(Keyword.IF)) { ... }
if (token.next!.isIdentifier) { ... }

// Check string value (for contextual keywords)
if (token.next!.lexeme == 'show') { ... }
```

## Listener events

The parser communicates through listener callbacks:

```dart
// In listener.dart — add your events:
void beginMyConstruct(Token keyword) {}
void endMyConstruct(Token keyword, Token semicolon) {}

// Or for simple constructs:
void handleMyConstruct(Token keyword) {}
```

Naming conventions:
- `begin*` / `end*` — paired events wrapping child parsing
- `handle*` — single event after the construct is fully parsed

## Common parsing helpers

| Method | Purpose |
|--------|---------|
| `parseExpression(token)` | Parse any expression |
| `parsePrimary(token, context)` | Parse a primary expression |
| `parseType(token)` | Parse a type annotation |
| `parseArguments(token)` | Parse `(arg1, arg2)` |
| `parseBlock(token, context)` | Parse `{ ... }` block |
| `ensureSemicolon(token)` | Require `;`, report error if missing |
| `ensureIdentifier(token, context)` | Require identifier |
| `expect(type, token)` | Require specific token type |
| `optional(type, token)` | Consume token if it matches, else return null |

## Repetition patterns

```dart
// Zero or more: parseFooStar
Token parseFooStar(Token token) {
  while (token.next!.isA(TokenType.FOO)) {
    token = parseFoo(token);
  }
  return token;
}

// One or more: parseFooPlus
Token parseFooPlus(Token token) {
  token = parseFoo(token);  // at least one
  while (token.next!.isA(TokenType.FOO)) {
    token = parseFoo(token);
  }
  return token;
}

// Optional: parseFooOpt
Token parseFooOpt(Token token) {
  if (token.next!.isA(TokenType.FOO)) {
    return parseFoo(token);
  }
  return token;
}
```

## Adding a new keyword

1. Add to `pkg/_fe_analyzer_shared/lib/src/scanner/token.dart`:
   ```dart
   static const Keyword MY_KEYWORD = Keyword("mykeyword", ...);
   ```

2. Update the keyword list and regenerate if needed.

## Parser test expectations

After modifying parser behavior:
```bash
./tools/sdks/dart-sdk/bin/dart pkg/front_end/tool/update_expectations.dart
```
