import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_strings.dart';
import '../firebase/firebase_providers.dart';
import '../providers/auth_provider.dart';

enum ReportTarget { place, flavor, checkIn, user }

const _reasons = <String>['spam', 'offensive', 'wrong', 'other'];

String _wireTarget(ReportTarget target) => switch (target) {
  ReportTarget.place => 'place',
  ReportTarget.flavor => 'flavor',
  ReportTarget.checkIn => 'check_in',
  ReportTarget.user => 'user',
};

/// Flags user content for review. Reports land in `reports/`, which only the
/// console can read (App Store guideline 1.2).
final class ReportButton extends ConsumerWidget {
  const ReportButton({
    required this.target,
    required this.targetId,
    this.color,
    super.key,
  });

  final ReportTarget target;
  final String targetId;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: ValueKey<String>('report-${target.name}-$targetId'),
    tooltip: AppStrings.reportTooltip,
    color: color,
    icon: const Icon(CupertinoIcons.flag),
    onPressed: () => showReportSheet(context, ref, target, targetId),
  );
}

Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref,
  ReportTarget target,
  String targetId,
) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              AppStrings.reportTitle,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final reason in _reasons)
            ListTile(
              key: ValueKey<String>('report-reason-$reason'),
              title: Text(AppStrings.reportReason(reason)),
              onTap: () => Navigator.of(sheetContext).pop(reason),
            ),
        ],
      ),
    ),
  );
  final uid = ref.read(currentUidProvider);
  if (reason == null || uid == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(firestoreProvider).collection('reports').add({
      'reporter_uid': uid,
      'target_type': _wireTarget(target),
      'target_id': targetId,
      'reason': reason,
      'created_at': FieldValue.serverTimestamp(),
    });
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.reportSent)),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.operationFailed)),
    );
  }
}
