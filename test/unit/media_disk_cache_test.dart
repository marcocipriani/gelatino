import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/services/media_cache/media_disk_cache_io.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('media_cache_test');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  FileMediaDiskCache cache({int maxTotalBytes = 1 << 20}) =>
      FileMediaDiskCache(() async => root, maxTotalBytes: maxTotalBytes);

  test('round-trips immutable paths and respects maxBytes', () async {
    final subject = cache();
    const path = 'check_ins/alice/ABCDEFGHIJKLMNOPQRST/1.jpg';
    await subject.write(path, Uint8List.fromList([1, 2, 3]));

    expect(await subject.read(path, maxBytes: 10), [1, 2, 3]);
    expect(await subject.read(path, maxBytes: 2), isNull);
    expect(await cache().read(path, maxBytes: 10), [1, 2, 3]);
  });

  test('never caches mutable staging uploads', () async {
    final subject = cache();
    const path = 'staging/alice/ABCDEFGHIJKLMNOPQRST.jpg';
    await subject.write(path, Uint8List.fromList([1]));

    expect(await subject.read(path, maxBytes: 10), isNull);
    expect(root.listSync(), isEmpty);
  });

  test('clear drops every entry', () async {
    final subject = cache();
    await subject.write('avatars/alice/v1.jpg', Uint8List.fromList([1]));
    await subject.clear();

    expect(await subject.read('avatars/alice/v1.jpg', maxBytes: 10), isNull);
  });

  test('trims the oldest files past the size cap', () async {
    final old = File('${root.path}/old')..writeAsBytesSync(List.filled(8, 0));
    old.setLastModifiedSync(DateTime(2020));
    final subject = cache(maxTotalBytes: 10);
    await subject.write('avatars/alice/v1.jpg', Uint8List(4));

    expect(old.existsSync(), isFalse);
    expect(
      await subject.read('avatars/alice/v1.jpg', maxBytes: 10),
      hasLength(4),
    );
  });

  test('an unavailable directory degrades to misses', () async {
    final subject = FileMediaDiskCache(() async => throw StateError('none'));
    await subject.write('avatars/alice/v1.jpg', Uint8List.fromList([1]));

    expect(await subject.read('avatars/alice/v1.jpg', maxBytes: 10), isNull);
  });
}
