import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hosting revalidates every unversioned web entrypoint', () {
    final config =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    final headers = (hosting['headers'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();

    expect(headers, isNotNull);
    final entrypointPolicy = headers!.singleWhere(
      (entry) =>
          entry['source'] ==
          '/@(index.html|flutter_bootstrap.js|main.dart.js|flutter_service_worker.js)',
    );
    expect(entrypointPolicy['headers'], [
      {'key': 'Cache-Control', 'value': 'no-cache, max-age=0, must-revalidate'},
    ]);
  });
}
