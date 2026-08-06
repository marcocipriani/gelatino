import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/timeline_providers.dart';
import 'package:gelatino/screens/timeline_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gelatino/widgets/semantic_state_button.dart';

import 'finders.dart';

final class AppDriver {
  AppDriver(this.tester);

  static const timeout = Duration(seconds: 10);
  static const pollInterval = Duration(milliseconds: 100);

  final WidgetTester tester;

  Future<void> waitForLabel(String label) =>
      waitFor(E2EFinders.text(label), 'text "$label"');

  Future<void> waitForRoute(String path) async {
    await waitUntil(() => currentRoute().path == path, 'route "$path"');
  }

  Future<void> waitFor(Finder finder, String description) async {
    await waitUntil(() => finder.evaluate().isNotEmpty, description);
  }

  Future<void> tapLabel(String label) async {
    final finder = E2EFinders.text(label);
    await waitFor(finder, 'tappable text "$label"');
    await _tap(finder.last, 'text "$label"');
  }

  Future<void> tapTextContaining(String value) async {
    final finder = E2EFinders.textContaining(value);
    await waitFor(finder, 'text containing "$value"');
    await _tap(finder.last, 'text containing "$value"');
  }

  Future<void> tapTooltip(String label) async {
    final finder = find.byTooltip(label);
    await waitFor(finder, 'control with tooltip "$label"');
    await _tap(finder.last, 'control with tooltip "$label"');
  }

  Future<void> tapEnabledButton(String label) async {
    final finder = find.ancestor(
      of: E2EFinders.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton && widget.onPressed != null,
        description: 'enabled button',
      ),
    );
    await waitFor(finder, 'enabled button "$label"');
    await _tap(finder.last, 'enabled button "$label"');
  }

  Future<void> ensureStateButtonSelected(
    String key, {
    required bool selected,
  }) async {
    final finder = E2EFinders.key(key);
    await waitUntil(() {
      if (finder.evaluate().isEmpty) return false;
      final button = tester.widget<SemanticStateButton>(finder);
      return button.onPressed != null;
    }, 'enabled state button "$key"');
    final button = tester.widget<SemanticStateButton>(finder);
    if (button.selected == selected) return;
    final callback = button.onPressed;
    expect(callback, isNotNull, reason: _failure('state button "$key"'));
    callback!();
    await tester.pump(pollInterval);
  }

  Future<void> activateEnabledButtonTwiceBeforePump(String label) async {
    final finder = find.ancestor(
      of: E2EFinders.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton && widget.onPressed != null,
        description: 'enabled button',
      ),
    );
    await waitFor(finder, 'enabled button "$label"');
    await tester.ensureVisible(finder.last);
    await tester.pump(const Duration(milliseconds: 250));
    final callback = tester.widget<ButtonStyleButton>(finder.last).onPressed;
    expect(callback, isNotNull, reason: _failure('enabled button "$label"'));
    callback!();
    callback();
    await tester.pump(pollInterval);
  }

  Future<void> tapKey(String value) async {
    final finder = E2EFinders.key(value);
    await waitFor(finder, 'key "$value"');
    await _tap(finder.first, 'key "$value"');
  }

  Future<void> enterAndSubmit(String fieldLabel, String value) async {
    final finder = E2EFinders.textField(fieldLabel);
    await waitFor(finder, 'text field "$fieldLabel"');
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(pollInterval);
  }

  Future<void> enterText(String fieldLabel, String value) async {
    final finder = E2EFinders.textField(fieldLabel);
    await waitFor(finder, 'text field "$fieldLabel"');
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump(pollInterval);
  }

  Future<void> selectChoiceChip(String label) async {
    final finder = find.widgetWithText(ChoiceChip, label);
    await waitUntil(() {
      if (finder.evaluate().isEmpty) return false;
      return tester.widget<ChoiceChip>(finder).onSelected != null;
    }, 'enabled choice chip "$label"');
    var chip = tester.widget<ChoiceChip>(finder);
    if (!chip.selected) await _tap(finder, 'choice chip "$label"');
    await waitUntil(() {
      chip = tester.widget<ChoiceChip>(finder);
      return chip.selected && chip.onSelected != null;
    }, 'selected choice chip "$label"');
  }

  Future<void> setCheckbox(String label, bool value) async {
    final finder = find.widgetWithText(CheckboxListTile, label);
    await waitFor(finder, 'checkbox "$label"');
    var tile = tester.widget<CheckboxListTile>(finder);
    if (tile.value != value) await _tap(finder, 'checkbox "$label"');
    await waitUntil(() {
      tile = tester.widget<CheckboxListTile>(finder);
      return tile.value == value && tile.onChanged != null;
    }, 'checkbox "$label" to become $value and enabled');
  }

  Future<void> setSwitch(String key, bool value) async {
    final finder = E2EFinders.key(key);
    await waitFor(finder, 'switch key "$key"');
    await waitUntil(() {
      return tester.widget<SwitchListTile>(finder).onChanged != null;
    }, 'enabled switch "$key"');
    final tile = tester.widget<SwitchListTile>(finder);
    if (tile.value == value) return;
    tile.onChanged!(value);
    await tester.pump(pollInterval);
  }

  Future<void> waitForDropdownValue(String key, Object expectedValue) async {
    final finder = E2EFinders.key(key);
    await waitFor(finder, 'dropdown "$key"');
    await waitUntil(() {
      final widget = tester.widget(finder);
      return switch (widget) {
        DropdownButton<ThemeMode>(:final value, :final onChanged) =>
          value == expectedValue && onChanged != null,
        DropdownButton<String>(:final value, :final onChanged) =>
          value == expectedValue && onChanged != null,
        _ => false,
      };
    }, 'dropdown "$key" value $expectedValue');
  }

  Future<void> selectDropdown({
    required String key,
    required String option,
    required Object expectedValue,
  }) async {
    await tapKey(key);
    await tapLabel(option);
    await waitUntil(() {
      final widget = tester.widget(E2EFinders.key(key));
      return switch (widget) {
        DropdownButton<ThemeMode>(:final value, :final onChanged) =>
          value == expectedValue && onChanged != null,
        DropdownButton<String>(:final value, :final onChanged) =>
          value == expectedValue && onChanged != null,
        _ => false,
      };
    }, 'dropdown "$key" to persist "$option"');
  }

  Future<void> pageBack() async {
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 250));
  }

  void expectAbsent(Finder finder, String description) {
    expect(finder, findsNothing, reason: _failure(description));
  }

  void expectExactlyOne(Finder finder, String description) {
    expect(finder, findsOneWidget, reason: _failure(description));
  }

  void expectNoFrameworkException(String description) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$description\n${_failure(description)}');
  }

  Future<void> waitForAbsent(Finder finder, String description) async {
    await waitUntil(() => finder.evaluate().isEmpty, 'absence of $description');
  }

  Future<Map<String, dynamic>> waitForDocument(
    String path, {
    required bool Function(Map<String, dynamic> data) matches,
    required String description,
  }) async {
    Map<String, dynamic>? latest;
    await waitUntil(() async {
      final snapshot = await FirebaseFirestore.instance.doc(path).get();
      latest = snapshot.data();
      return latest != null && matches(latest!);
    }, '$description at $path');
    return latest!;
  }

  Future<void> waitForMissingDocument(String path, String description) async {
    await waitUntil(() async {
      final snapshot = await FirebaseFirestore.instance.doc(path).get();
      return !snapshot.exists;
    }, '$description at $path');
  }

  Future<Map<String, dynamic>> waitForCollectionDocument(
    String path, {
    required bool Function(Map<String, dynamic> data) matches,
    required String description,
  }) async {
    Map<String, dynamic>? latest;
    await waitUntil(() async {
      final snapshot = await FirebaseFirestore.instance.collection(path).get();
      for (final document in snapshot.docs) {
        final data = document.data();
        if (matches(data)) {
          latest = data;
          return true;
        }
      }
      return false;
    }, '$description in $path');
    return latest!;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  waitForQueryDocuments(
    String path, {
    required String whereField,
    required Object isEqualTo,
    required bool Function(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    )
    matches,
    required String description,
  }) async {
    var latest = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    try {
      await waitUntil(() async {
        final snapshot = await FirebaseFirestore.instance
            .collection(path)
            .where(whereField, isEqualTo: isEqualTo)
            .get();
        latest = snapshot.docs;
        return matches(latest);
      }, '$description in $path where $whereField == $isEqualTo');
    } on TestFailure catch (error) {
      final documents = latest
          .map((document) => '${document.id}: ${document.data()}')
          .join('\n');
      throw TestFailure(
        '$error\nLatest matching query documents: '
        '${documents.isEmpty ? '<none>' : documents}',
      );
    }
    return latest;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  waitForArrayQueryDocuments(
    String path, {
    required String whereField,
    required Object arrayContains,
    required bool Function(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    )
    matches,
    required String description,
  }) async {
    var latest = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    await waitUntil(() async {
      final snapshot = await FirebaseFirestore.instance
          .collection(path)
          .where(whereField, arrayContains: arrayContains)
          .get();
      latest = snapshot.docs;
      return matches(latest);
    }, '$description in $path where $whereField contains $arrayContains');
    return latest;
  }

  Future<Map<String, dynamic>> waitForJsonPreference(
    String key, {
    required bool Function(Map<String, dynamic> data) matches,
    required String description,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    Map<String, dynamic>? latest;
    await waitUntil(() {
      final encoded = preferences.getString(key);
      if (encoded == null) return false;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return false;
      latest = decoded;
      return matches(decoded);
    }, '$description in preference $key');
    return latest!;
  }

  Future<void> waitUntil(
    FutureOr<bool> Function() predicate,
    String description,
  ) async {
    final stopwatch = Stopwatch()..start();
    Object? lastError;
    while (stopwatch.elapsed < timeout) {
      await tester.pump(pollInterval);
      final frameworkError = tester.takeException();
      if (frameworkError != null) {
        final overflowingFlexes = _overflowingFlexDiagnostics();
        throw TestFailure(
          'Framework exception while waiting for $description:\n'
          '$frameworkError\n'
          'Overflowing flexes:\n$overflowingFlexes\n'
          '${_failure(description)}',
        );
      }
      try {
        if (await predicate()) return;
      } on Object catch (error) {
        lastError = error;
      }
    }
    final suffix = lastError == null ? '' : '\nLast error: $lastError';
    throw TestFailure('${_failure(description)}$suffix');
  }

  String _overflowingFlexDiagnostics() {
    final matches = <String>[];

    void visit(RenderObject object) {
      if (object is RenderFlex && object.toString().contains('OVERFLOWING')) {
        matches.add(object.toStringDeep());
      }
      object.visitChildren(visit);
    }

    for (final view in RendererBinding.instance.renderViews) {
      visit(view);
    }
    return matches.isEmpty ? '<none>' : matches.join('\n');
  }

  Future<void> _tap(Finder finder, String description) async {
    try {
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(finder);
      await tester.pump(pollInterval);
    } on Object catch (error) {
      throw TestFailure('${_failure(description)}\nTap error: $error');
    }
  }

  Uri currentRoute() {
    final navigators = find.byType(Navigator, skipOffstage: false);
    if (navigators.evaluate().isEmpty) return Uri();
    try {
      return GoRouter.of(
        tester.element(navigators.first),
      ).routeInformationProvider.value.uri;
    } on Object {
      return Uri();
    }
  }

  String _failure(String missing) {
    final visible = tester
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .map((widget) => widget.data)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .take(30)
        .join(' | ');
    final timeline = _timelineDiagnostics();
    return 'Missing $missing after ${timeout.inSeconds}s. '
        'Route: ${currentRoute()}.$timeline Visible text: $visible';
  }

  String _timelineDiagnostics() {
    final finder = find.byType(TimelineScreen, skipOffstage: false);
    if (finder.evaluate().isEmpty) return '';
    try {
      final container = ProviderScope.containerOf(tester.element(finder.last));
      final state = container.read(timelineProvider);
      return ' Timeline: uid=${container.read(currentUidProvider)}, '
          'items=${state.items.length}, initial=${state.isInitialLoading}, '
          'more=${state.isLoadingMore}, auth=${state.authorizationStatus}, '
          'friends=${state.acceptedFriendCount}, failure=${state.failure}.';
    } on Object catch (error) {
      return ' Timeline diagnostics unavailable: $error.';
    }
  }
}
