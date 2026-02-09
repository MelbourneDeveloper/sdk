// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// SharedOptions=--enable-experiment=record-spreads

/// Test error cases for record spreading.

void main() {
  // Spread non-record type: int.
  var x = 42;
  var r1 = (...x);
  //          ^
  // [analyzer] unspecified
  // [cfe] unspecified

  // Spread dynamic.
  dynamic d = (1, 2);
  var r2 = (...d);
  //          ^
  // [analyzer] unspecified
  // [cfe] unspecified

  // Spread abstract Record type.
  Record rec = (1, 2);
  var r3 = (...rec);
  //          ^^^
  // [analyzer] unspecified
  // [cfe] unspecified

  // Spread generic bounded by Record.
  spreadGeneric<(int, int)>((1, 2));

  // Null-aware spread is not supported.
  (int, int)? maybePoint = (1, 2);
  var r4 = (...?maybePoint);
  //          ^^
  // [analyzer] unspecified
  // [cfe] unspecified

  // Duplicate named field from spread + explicit.
  var named = (a: 1, b: 2);
  var r5 = (...named, a: 3);
  //                  ^
  // [analyzer] unspecified
  // [cfe] unspecified

  // Duplicate named field from two spreads.
  var s1 = (x: 1);
  var s2 = (x: 2);
  var r6 = (...s1, ...s2);
  //               ^^
  // [analyzer] unspecified
  // [cfe] unspecified

  // Spread a String (not a record).
  var str = 'hello';
  var r7 = (...str);
  //          ^^^
  // [analyzer] unspecified
  // [cfe] unspecified

  // Spread a List (not a record).
  var list = [1, 2, 3];
  var r8 = (...list);
  //          ^^^^
  // [analyzer] unspecified
  // [cfe] unspecified
}

void spreadGeneric<T extends Record>(T value) {
  var r = (...value);
  //         ^^^^^
  // [analyzer] unspecified
  // [cfe] unspecified
}
