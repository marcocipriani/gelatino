import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/design/responsive.dart';

void main() {
  group('ResponsiveClass.fromWidth', () {
    test('keeps widths through 599 compact', () {
      expect(ResponsiveClass.fromWidth(0), ResponsiveClass.compact);
      expect(ResponsiveClass.fromWidth(599), ResponsiveClass.compact);
    });

    test('keeps medium mobile from 600 through 1023', () {
      expect(ResponsiveClass.fromWidth(600), ResponsiveClass.medium);
      expect(ResponsiveClass.fromWidth(1023), ResponsiveClass.medium);
    });

    test('switches to wide at 1024', () {
      expect(ResponsiveClass.fromWidth(1024), ResponsiveClass.wide);
      expect(ResponsiveClass.fromWidth(1440), ResponsiveClass.wide);
    });
  });

  test('each responsive class selects its exact horizontal page padding', () {
    expect(ResponsiveClass.compact.horizontalPadding, 16);
    expect(ResponsiveClass.medium.horizontalPadding, 24);
    expect(ResponsiveClass.wide.horizontalPadding, 32);
  });

  test('layout constants retain the A1 content and target caps', () {
    expect(AppLayout.maxContent, 1280);
    expect(AppLayout.touchTarget, 44);
    expect(AppFocus.ringWidth, 2);
    expect(AppBreakpoints.compactMax, 599);
    expect(AppBreakpoints.wideMin, 1024);
  });
}
