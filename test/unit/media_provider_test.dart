import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/providers/media_provider.dart';
import 'package:gelatino/services/storage_service.dart';

void main() {
  test('media key includes the complete path and exact byte limit', () {
    const first = AuthenticatedMediaKey('check_ins/alice/id/1.jpg', 10);
    const same = AuthenticatedMediaKey('check_ins/alice/id/1.jpg', 10);
    const newVersion = AuthenticatedMediaKey('check_ins/alice/id/2.jpg', 10);
    const newLimit = AuthenticatedMediaKey('check_ins/alice/id/1.jpg', 11);

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(newVersion));
    expect(first, isNot(newLimit));
    expect(checkInMediaMaxBytes, 5 * 1024 * 1024);
    expect(avatarMediaMaxBytes, 2 * 1024 * 1024);
  });

  test('one watched key forwards path and limit only once', () async {
    final gateway = _MediaGateway()..result = Uint8List.fromList([1, 2]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    const key = AuthenticatedMediaKey('check_ins/alice/id/1.jpg', 123);
    final first = container.listen(mediaBytesProvider(key), (_, _) {});
    final second = container.listen(mediaBytesProvider(key), (_, _) {});
    addTearDown(first.close);
    addTearDown(second.close);

    expect(await container.read(mediaBytesProvider(key).future), [1, 2]);
    expect(await container.read(mediaBytesProvider(key).future), [1, 2]);
    expect(gateway.reads, [(path: key.path, maxBytes: key.maxBytes)]);
  });

  test('different version or limit creates a distinct request', () async {
    final gateway = _MediaGateway()..result = Uint8List.fromList([1]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    const keys = <AuthenticatedMediaKey>[
      AuthenticatedMediaKey('avatars/alice/v1.jpg', 20),
      AuthenticatedMediaKey('avatars/alice/v2.jpg', 20),
      AuthenticatedMediaKey('avatars/alice/v1.jpg', 21),
    ];

    for (final key in keys) {
      await container.read(mediaBytesProvider(key).future);
    }

    expect(gateway.reads, [
      (path: keys[0].path, maxBytes: keys[0].maxBytes),
      (path: keys[1].path, maxBytes: keys[1].maxBytes),
      (path: keys[2].path, maxBytes: keys[2].maxBytes),
    ]);
  });

  test(
    'missing stays missing and invalid/error requests fail closed',
    () async {
      final gateway = _MediaGateway();
      final container = _container(gateway);
      addTearDown(container.dispose);

      expect(
        await container.read(
          mediaBytesProvider(
            const AuthenticatedMediaKey('avatars/alice/missing.jpg', 20),
          ).future,
        ),
        isNull,
      );
      const invalidKey = AuthenticatedMediaKey('../hostile.jpg', 20);
      final invalidSubscription = container.listen(
        mediaBytesProvider(invalidKey),
        (_, _) {},
      );
      addTearDown(invalidSubscription.close);
      await expectLater(
        container.read(mediaBytesProvider(invalidKey).future),
        throwsFormatException,
      );

      gateway.error = StateError('offline');
      const errorKey = AuthenticatedMediaKey('avatars/alice/error.jpg', 20);
      final errorSubscription = container.listen(
        mediaBytesProvider(errorKey),
        (_, _) {},
      );
      addTearDown(errorSubscription.close);
      await expectLater(
        container.read(mediaBytesProvider(errorKey).future),
        throwsStateError,
      );
    },
  );

  test('retry invalidates only the failed request key', () async {
    final gateway = _MediaGateway()..result = Uint8List.fromList([1]);
    final container = _container(gateway);
    addTearDown(container.dispose);
    const first = AuthenticatedMediaKey('avatars/alice/v1.jpg', 20);
    const second = AuthenticatedMediaKey('avatars/alice/v2.jpg', 20);
    final firstSubscription = container.listen(
      mediaBytesProvider(first),
      (_, _) {},
    );
    final secondSubscription = container.listen(
      mediaBytesProvider(second),
      (_, _) {},
    );
    addTearDown(firstSubscription.close);
    addTearDown(secondSubscription.close);

    await container.read(mediaBytesProvider(first).future);
    await container.read(mediaBytesProvider(second).future);
    container.invalidate(mediaBytesProvider(first));
    await container.read(mediaBytesProvider(first).future);

    expect(
      gateway.reads.where((read) => read.path == first.path),
      hasLength(2),
    );
    expect(
      gateway.reads.where((read) => read.path == second.path),
      hasLength(1),
    );
  });
}

ProviderContainer _container(_MediaGateway gateway) => ProviderContainer(
  overrides: [
    storageServiceProvider.overrideWithValue(
      StorageService.forTesting(gateway),
    ),
  ],
);

final class _MediaGateway implements StorageObjectGateway {
  final List<({String path, int maxBytes})> reads = [];
  Uint8List? result;
  Object? error;

  @override
  Future<Uint8List?> read(String path, int maxBytes) async {
    reads.add((path: path, maxBytes: maxBytes));
    if (error case final current?) throw current;
    return result;
  }

  @override
  Future<String> put(String path, Uint8List bytes, SettableMetadata metadata) =>
      throw UnimplementedError();
}
