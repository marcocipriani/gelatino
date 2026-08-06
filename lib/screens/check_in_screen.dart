import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/check_in_flow_provider.dart';
import '../providers/timeline_providers.dart';
import 'check_in/check_in_flow.dart';
import '../constants/app_strings.dart';

final class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({
    super.key,
    this.placeId,
    this.prefillFriendId,
    this.onCompleted,
    this.onClose,
  });

  final String? placeId;
  final String? prefillFriendId;
  final VoidCallback? onCompleted;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text(AppStrings.checkInLoginRequired)),
      );
    }
    return CheckInFlow(
      key: ValueKey<String>('check-in-flow-$uid'),
      uid: uid,
      placeId: placeId,
      prefillFriendId: prefillFriendId,
      onExit: onClose ?? () => GoRouter.maybeOf(context)?.go('/timeline'),
      onCompleted:
          onCompleted ??
          () async {
            final checkInId = ref
                .read(checkInFlowProvider(uid))
                .publicationDraftId;
            if (checkInId != null) {
              await ref.read(timelineProjectionWaiterProvider)(uid, checkInId);
            }
            if (context.mounted) {
              GoRouter.maybeOf(context)?.go('/timeline');
            }
          },
    );
  }
}
