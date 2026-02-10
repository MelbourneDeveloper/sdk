// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// SharedOptions=--enable-experiment=record-spreads
// dart format off

/// Test error cases for record spreading.

void main() {
  // Spread non-record type: int.
  var x = 42;
  var r1 = (...x); //# 01: compile-time error

  // Spread dynamic.
  dynamic d = (1, 2);
  var r2 = (...d); //# 02: compile-time error

  // Spread abstract Record type.
  Record rec = (1, 2);
  var r3 = (...rec); //# 03: compile-time error

  // Spread generic bounded by Record.
  spreadGeneric<(int, int)>((1, 2)); //# 04: compile-time error

  // Null-aware spread is not supported.
  (int, int)? maybePoint = (1, 2);
  var r4 = (...?maybePoint); //# 05: compile-time error

  // Duplicate named field from spread + explicit.
  var named = (a: 1, b: 2);
  var r5 = (...named, a: 3); //# 06: compile-time error

  // Duplicate named field from two spreads.
  var s1 = (x: 1);
  var s2 = (x: 2);
  var r6 = (...s1, ...s2); //# 07: compile-time error

  // Spread a String (not a record).
  var str = 'hello';
  var r7 = (...str); //# 08: compile-time error

  // Spread a List (not a record).
  var list = [1, 2, 3];
  var r8 = (...list); //# 09: compile-time error
}

void spreadGeneric<T extends Record>(T value) {
  var r = (...value); //# 04: continued
}
