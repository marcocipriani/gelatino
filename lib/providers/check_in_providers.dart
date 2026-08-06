import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';
import '../repositories/check_in_repository.dart';

final checkInCallableDataSourceProvider = Provider<CheckInCallableDataSource>(
  (ref) => FirebaseCheckInCallableDataSource(ref.watch(functionsProvider)),
);

final checkInRepositoryProvider = Provider<CheckInRepository>(
  (ref) =>
      CallableCheckInRepository(ref.watch(checkInCallableDataSourceProvider)),
);
