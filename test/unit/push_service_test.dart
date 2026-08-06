import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/services/push_service.dart';

void main() {
  group('PushService.tokenPayload', () {
    test('token document payload is exactly platform + updated_at', () {
      final payload = PushService.tokenPayload(platform: 'web');
      expect(payload.keys.toSet(), {'platform', 'updated_at'});
      expect(payload['platform'], 'web');
    });

    test('carries android/ios platform values through unchanged', () {
      expect(PushService.tokenPayload(platform: 'android')['platform'], 'android');
      expect(PushService.tokenPayload(platform: 'ios')['platform'], 'ios');
    });

    test('updated_at is the serverTimestamp sentinel', () {
      final payload = PushService.tokenPayload(platform: 'web');
      expect(payload['updated_at'], FieldValue.serverTimestamp());
    });
  });

  test(
    'attachRefreshListenerOnce subscribes to onTokenRefresh at most once',
    () {
      final messaging = _RefreshCountingMessaging();
      final service = PushService(_UnusedFirestore(), messaging);

      service.attachRefreshListenerOnce('alice');
      service.attachRefreshListenerOnce('alice');

      expect(messaging.onTokenRefreshReads, 1);
      expect(service.hasAttachedRefreshListener, isTrue);
      expect(messaging.liveSubscriptionCount, 1);
    },
  );

  test(
    'clearForSignOut then attach as a different uid cancels the stale listener',
    () async {
      final messaging = _RefreshCountingMessaging();
      final service = PushService(_NoopFirestore(), messaging);

      service.attachRefreshListenerOnce('alice');
      final aliceController = messaging.controllers.single;
      expect(aliceController.hasListener, isTrue);

      await service.clearForSignOut('alice');
      expect(aliceController.hasListener, isFalse);
      expect(messaging.liveSubscriptionCount, 0);

      service.attachRefreshListenerOnce('bob');
      expect(messaging.liveSubscriptionCount, 1);
      expect(messaging.controllers.last.hasListener, isTrue);
    },
  );

  test(
    'switching uid directly cancels the previous listener and attaches the new one',
    () {
      final messaging = _RefreshCountingMessaging();
      final service = PushService(_UnusedFirestore(), messaging);

      service.attachRefreshListenerOnce('alice');
      final aliceController = messaging.controllers.single;

      service.attachRefreshListenerOnce('bob');

      expect(aliceController.hasListener, isFalse);
      expect(messaging.liveSubscriptionCount, 1);
      expect(messaging.controllers.last.hasListener, isTrue);
      expect(messaging.onTokenRefreshReads, 2);
    },
  );
}

class _RefreshCountingMessaging implements FirebaseMessaging {
  int onTokenRefreshReads = 0;
  final List<StreamController<String>> controllers = [];

  int get liveSubscriptionCount =>
      controllers.where((controller) => controller.hasListener).length;

  @override
  Stream<String> get onTokenRefresh {
    onTokenRefreshReads++;
    // A fresh broadcast controller per subscribe call lets the test observe
    // each attach's own `hasListener` state independently, so cancellation
    // of a stale (e.g. previous-uid) listener is distinguishable from a
    // freshly attached one.
    final controller = StreamController<String>.broadcast();
    controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<String?> getToken({String? vapidKey, String? serviceWorkerScriptPath}) async => null;

  @override
  Future<void> deleteToken() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
