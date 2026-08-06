import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../models/public_profile.dart';
import '../models/user_profile.dart';
import '../models/user_settings.dart';
import '../repositories/profile_repository.dart';
import 'auth_provider.dart';

final profileDataSourceProvider = Provider<ProfileDataSource>((ref) {
  return FirestoreProfileDataSource(ref.watch(firestoreProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileDataSourceProvider));
});

final ownProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<UserProfile?>.value(null);
  return _deferEvents(
    ref.watch(profileRepositoryProvider).watchOwnProfile(uid),
  );
});

final ownSettingsProvider = StreamProvider<UserSettings?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<UserSettings?>.value(null);
  return _deferEvents(
    ref.watch(profileRepositoryProvider).watchOwnSettings(uid),
  );
});

final publicProfileProvider = StreamProvider.family<PublicProfile?, String>((
  ref,
  uid,
) {
  return _deferEvents(
    ref.watch(profileRepositoryProvider).watchPublicProfile(uid),
  );
});

Stream<T> _deferEvents<T>(Stream<T> source) {
  return source.asyncMap((value) => Future<T>.value(value));
}

final publicProfileSearchProvider =
    FutureProvider.family<List<PublicProfile>, String>((ref, query) {
      return ref.watch(profileRepositoryProvider).searchPublicProfiles(query);
    });

final serverPointsProvider = Provider<int?>((ref) {
  return ref.watch(ownProfileProvider).value?.points;
});

final defaultCollectionViewProvider = Provider<String?>((ref) {
  return ref.watch(ownSettingsProvider).value?.defaultCollectionView;
});
