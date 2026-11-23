import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/constants/app_strings.dart';
import 'package:gelatino/providers/gelato_invite_providers.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/widgets/authenticated_shell.dart';

void main() {
  // 1000, not 844, for landscape: the test font is far wider than Jakarta.
  for (final size in const [Size(390, 844), Size(1000, 390), Size(1280, 860)]) {
    testWidgets(
      'screen readers reach the header above a routed body at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              friendsBadgeCountProvider.overrideWithValue(0),
              ownProfileProvider.overrideWith((ref) => Stream.value(null)),
            ],
            child: MaterialApp(
              home: AuthenticatedShell(
                location: '/collection',
                // As ShellRoute does: the body is a Navigator, whose modal
                // barrier blocks the semantics painted before it.
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('body')),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.semantics.byLabel(AppStrings.shellOpenSettings), findsOne);
        expect(find.semantics.byLabel(AppStrings.shellOpenProfile), findsOne);
        expect(find.semantics.byLabel('body'), findsOne);
        semantics.dispose();
      },
    );
  }
}
