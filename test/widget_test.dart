import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gelatino/screens/login_screen.dart';

void main() {
  testWidgets('Login screen visual components test', (WidgetTester tester) async {
    // Build the login screen.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify that the logo "Gelatino" is displayed.
    expect(find.text('Gelatino'), findsOneWidget);

    // Verify that the login button is displayed.
    expect(find.text('Accedi con Google'), findsOneWidget);
  });
}
