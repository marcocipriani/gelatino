import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

abstract final class E2EFinders {
  static Finder text(String label) => find.text(label);

  static Finder textContaining(String value) => find.textContaining(value);

  static Finder semantics(String label) => find.bySemanticsLabel(label);

  static Finder key(String value) => find.byKey(ValueKey<String>(value));

  static Finder textField(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField labelled "$label"',
  );
}
