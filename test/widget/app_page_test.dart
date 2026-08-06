import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/widgets/app_page.dart';

void main() {
  const childKey = Key('app-page-child');

  Future<void> pumpPage(
    WidgetTester tester, {
    required double width,
    bool fullBleed = false,
    Widget? child,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPage(
            fullBleed: fullBleed,
            child:
                child ??
                const SizedBox(
                  key: childKey,
                  width: double.infinity,
                  height: 20,
                ),
          ),
        ),
      ),
    );
  }

  testWidgets('uses compact padding at 390', (tester) async {
    await pumpPage(tester, width: 390);

    expect(tester.getTopLeft(find.byKey(childKey)).dx, 16);
    expect(tester.getSize(find.byKey(childKey)).width, 358);
  });

  testWidgets('uses medium padding at 768', (tester) async {
    await pumpPage(tester, width: 768);

    expect(tester.getTopLeft(find.byKey(childKey)).dx, 24);
    expect(tester.getSize(find.byKey(childKey)).width, 720);
  });

  testWidgets('uses wide padding at 1024', (tester) async {
    await pumpPage(tester, width: 1024);

    expect(tester.getTopLeft(find.byKey(childKey)).dx, 32);
    expect(tester.getSize(find.byKey(childKey)).width, 960);
  });

  testWidgets('centers content capped at 1280 on 1440', (tester) async {
    await pumpPage(tester, width: 1440);

    expect(tester.getTopLeft(find.byKey(childKey)).dx, 80);
    expect(tester.getSize(find.byKey(childKey)).width, 1280);
  });

  testWidgets('full bleed explicitly opts out of padding and cap', (
    tester,
  ) async {
    await pumpPage(tester, width: 1440, fullBleed: true);

    expect(tester.getTopLeft(find.byKey(childKey)).dx, 0);
    expect(tester.getSize(find.byKey(childKey)).width, 1440);
  });

  testWidgets('constrains an oversized child without horizontal overflow', (
    tester,
  ) async {
    await pumpPage(
      tester,
      width: 390,
      child: const SizedBox(key: childKey, width: 2000, height: 20),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(childKey)).width, 358);
  });

  testWidgets(
    'uses finite MediaQuery width and medium padding when unbounded',
    (tester) async {
      late BoxConstraints receivedConstraints;
      await tester.binding.setSurfaceSize(const Size(768, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(size: Size(768, 700)),
              child: Row(
                children: [
                  AppPage(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        receivedConstraints = constraints;
                        return const SizedBox(
                          key: childKey,
                          width: double.infinity,
                          height: 20,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(receivedConstraints.maxWidth.isFinite, isTrue);
      expect(receivedConstraints.maxWidth, 720);
      expect(tester.getTopLeft(find.byKey(childKey)).dx, 24);
      expect(tester.getSize(find.byKey(childKey)).width, 720);
    },
  );

  testWidgets('full bleed stays finite when horizontally unbounded', (
    tester,
  ) async {
    late BoxConstraints receivedConstraints;
    await tester.binding.setSurfaceSize(const Size(768, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(768, 700)),
            child: Row(
              children: [
                AppPage(
                  fullBleed: true,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      receivedConstraints = constraints;
                      return const SizedBox(
                        key: childKey,
                        width: double.infinity,
                        height: 20,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(receivedConstraints.maxWidth.isFinite, isTrue);
    expect(receivedConstraints.maxWidth, 768);
    expect(tester.getTopLeft(find.byKey(childKey)).dx, 0);
    expect(tester.getSize(find.byKey(childKey)).width, 768);
  });
}
