# Dart SDK Test Formats

## Standard tests

Most tests are Dart scripts that should run without error and exit with code 0:

```dart
import 'package:expect/expect.dart';

main() {
  Expect.equals(3, 1 + 2);
}
```

Use `package:expect` (not `package:test`) for language/corelib tests — it minimizes dependencies on the code being tested.

For async tests, use `package:expect/async_helper.dart`.

## Multitests

Lines with `//#` markers are split into separate test files per section:

```dart
class A {
  foo(); //# 00: compile-time error
  static bar(); //# 01: compile-time error
}
```

This creates three tests:
- `none` — just `class A {}` (should pass)
- `00` — includes `foo()` line (expects compile-time error)
- `01` — includes `static bar()` line (expects compile-time error)

Outcome markers: `compile-time error`, `runtime error`, `static type warning`, `ok` (or omitted = pass).

## Static error tests

Precise error location testing for analyzer and CFE:

```dart
int i = "not int";
//      ^^^^^^^^^
// [analyzer] COMPILE_TIME_ERROR.INVALID_ASSIGNMENT
// [cfe] A value of type 'String' can't be assigned to a variable of type 'int'.
```

Format:
1. Line with the error
2. Comment with `^` carets marking column and length
3. `// [analyzer] ERROR_CODE` — expected analyzer error code
4. `// [cfe] Error message text` — expected CFE error message

Multiple errors on the same line:
```dart
int i = "not int" / 345;
//      ^^^^^^^^^
// [analyzer] COMPILE_TIME_ERROR.INVALID_ASSIGNMENT
//                  ^^^
// [analyzer] COMPILE_TIME_ERROR.UNDEFINED_OPERATOR
```

Explicit location (for errors starting before column 2 or spanning lines):
```dart
var x = bad;
// [error line 1, column 9, length 3]
// [analyzer] COMPILE_TIME_ERROR.UNDEFINED_IDENTIFIER
// [cfe] Undefined name 'bad'.
```

Use `unspecified` when the exact error code/message isn't known yet:
```dart
var x = bad;
//      ^^^
// [analyzer] unspecified
// [cfe] unspecified
```

## Web static errors

For DDC/dart2js-specific restrictions:

```dart
@JS()
external int get foo;
//               ^^^
// [web] JS interop requires...
```

## Updating test expectations

After changing error messages:
```bash
dart pkg/test_runner/tool/update_static_error_tests.dart -u "**/test_file.dart"
```

After changing parser behavior:
```bash
dart pkg/front_end/tool/update_expectations.dart
```

## Test file naming

- Test files: `*_test.dart`
- Tests directory: `tests/language/`, `tests/corelib/`, etc.
- Group by feature: `tests/language/record_spreads/`

## Experimental features in tests

Enable experimental features in tests by adding a comment header:

```dart
// SharedOptions=--enable-experiment=record-spreads

import 'package:expect/expect.dart';

main() {
  // test code using experimental feature
}
```
