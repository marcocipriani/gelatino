import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Functions package runner resolves the repository root', () async {
    final repository = Directory.current.absolute.path;
    final temporary = await Directory.systemTemp.createTemp(
      'gelatino-e2e-runner-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final bin = await Directory('${temporary.path}/bin').create();
    final log = File('${temporary.path}/commands.log');
    final npm = File('${bin.path}/npm')
      ..writeAsStringSync(r'''#!/usr/bin/env bash
printf 'npm|%s|%s\n' "$PWD" "$*" >> "$E2E_RUNNER_LOG"
''');
    final flutter = File('${bin.path}/flutter')
      ..writeAsStringSync(r'''#!/usr/bin/env bash
printf 'flutter|%s|%s\n' "$PWD" "$*" >> "$E2E_RUNNER_LOG"
''');
    final chmod = await Process.run('chmod', ['+x', npm.path, flutter.path]);
    expect(chmod.exitCode, 0, reason: chmod.stderr.toString());

    final whichNpm = await Process.run('which', ['npm']);
    expect(whichNpm.exitCode, 0, reason: whichNpm.stderr.toString());
    final result = await Process.run(
      whichNpm.stdout.toString().trim(),
      ['--prefix', 'functions', 'run', 'test:e2e'],
      workingDirectory: repository,
      environment: {
        ...Platform.environment,
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'E2E_RUNNER_LOG': log.path,
        'FIRESTORE_EMULATOR_HOST': '127.0.0.1:8080',
        'FIREBASE_AUTH_EMULATOR_HOST': '127.0.0.1:9099',
        'FIREBASE_STORAGE_EMULATOR_HOST': '127.0.0.1:9199',
      },
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(log.readAsLinesSync(), [
      'npm|$repository|--prefix functions run seed:e2e',
      'flutter|$repository|drive --driver=test_driver/integration_test.dart '
          '--target=integration_test/two_user_journey_test.dart -d web-server '
          '--dart-define=USE_FIREBASE_EMULATORS=true '
          '--dart-define=E2E_TESTING=true',
    ]);
  });

  test('web E2E runner seeds exactly once before flutter drive', () {
    final source = File('tool/run_web_e2e.sh').readAsStringSync();
    const seed = 'npm --prefix functions run seed:e2e';
    expect(source, contains('set -euo pipefail'));
    expect(RegExp(RegExp.escape(seed)).allMatches(source), hasLength(1));
    expect(source.indexOf(seed), lessThan(source.indexOf('flutter drive')));
    expect(source, contains('--driver=test_driver/integration_test.dart'));
    expect(
      source,
      contains('--target=integration_test/two_user_journey_test.dart'),
    );
    expect(source, contains('-d web-server'));
    expect(source, isNot(contains('-d chrome')));
    expect(source, contains('--dart-define=USE_FIREBASE_EMULATORS=true'));
    expect(source, contains('--dart-define=E2E_TESTING=true'));
    for (final variable in <String>[
      'FIRESTORE_EMULATOR_HOST',
      'FIREBASE_AUTH_EMULATOR_HOST',
      'FIREBASE_STORAGE_EMULATOR_HOST',
    ]) {
      expect(source, contains('\${$variable:?'));
    }
  });

  test('driver and Functions package expose the local E2E commands', () {
    final driver = File('test_driver/integration_test.dart').readAsStringSync();
    final package =
        jsonDecode(File('functions/package.json').readAsStringSync())
            as Map<String, dynamic>;
    final scripts = package['scripts'] as Map<String, dynamic>;

    expect(driver, contains('integrationDriver()'));
    expect(
      scripts['seed:e2e'],
      'npm run build && node lib/test/seed/e2e_seed.js',
    );
    expect(scripts['test:e2e'], 'bash ../tool/run_web_e2e.sh');
  });
}
