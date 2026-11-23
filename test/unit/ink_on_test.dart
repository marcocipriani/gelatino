import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/design/app_tokens.dart';

void main() {
  test('inkOn clears AA on any colour a user can pick', () {
    for (var r = 0; r < 256; r += 5) {
      for (var g = 0; g < 256; g += 5) {
        for (var b = 0; b < 256; b += 5) {
          final fill = Color.fromARGB(255, r, g, b);
          final a = fill.computeLuminance();
          final i = inkOn(fill).computeLuminance();
          final ratio = a > i ? (a + .05) / (i + .05) : (i + .05) / (a + .05);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '$fill');
        }
      }
    }
  });
}
