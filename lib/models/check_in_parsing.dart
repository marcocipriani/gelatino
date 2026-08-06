import 'package:cloud_firestore/cloud_firestore.dart';

import 'check_in.dart';
import 'firestore_parsing.dart';

List<CheckIn> parseCheckInSnapshots(
  Iterable<DocumentSnapshot<Map<String, dynamic>>> snapshots,
) => List<CheckIn>.unmodifiable(
  snapshots.map(parseCheckInSnapshot).whereType<CheckIn>(),
);

CheckIn? parseCheckInSnapshot(
  DocumentSnapshot<Map<String, dynamic>> snapshot,
) => parseOrReport<CheckIn>(
  path: 'check_ins/${snapshot.id}',
  parse: () {
    final data = snapshot.data();
    if (data == null) {
      throw const FormatException('document: expected data');
    }
    if (data['schema_version'] == 2) {
      return CheckIn.fromFirestore(snapshot);
    }
    if (!data.containsKey('schema_version') &&
        data.containsKey('user_summary')) {
      return CheckIn.fromLegacyFirestore(snapshot);
    }
    throw const FormatException('check-in: unknown schema');
  },
);
