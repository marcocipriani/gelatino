import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/public_profile.dart';
import '../../widgets/share/share_check_in_card.dart';
import '../../constants/app_strings.dart';

final class ShareStep extends StatelessWidget {
  const ShareStep({
    required this.placeName,
    required this.typeName,
    required this.flavorNames,
    required this.shareFlavors,
    required this.rating,
    required this.reviewText,
    required this.hasPrivatePhoto,
    required this.photoBytes,
    required this.friends,
    required this.selectedFriendIds,
    required this.selectedFriendNames,
    required this.enabled,
    required this.onFriendChanged,
    required this.onRetryFriends,
    required this.onClearSelectedFriends,
    required this.publicationFailed,
    super.key,
  });

  final String placeName;
  final String typeName;
  final List<String> flavorNames;

  /// Same flavors as [flavorNames], shaped for [ShareCheckInCard]
  /// (`name`/`color_hex`) — kept separate so the summary card above stays a
  /// plain name list while the share card gets the branded chip colors.
  final List<Map<String, dynamic>> shareFlavors;
  final int rating;
  final String reviewText;
  final bool hasPrivatePhoto;

  /// The staged check-in photo, decoded locally (not yet uploaded). Needed
  /// to render the share card's photo; the secondary share button is hidden
  /// until this is available.
  final Uint8List? photoBytes;
  final AsyncValue<List<PublicProfile>> friends;
  final List<String> selectedFriendIds;
  final List<String> selectedFriendNames;
  final bool enabled;
  final void Function(String uid, bool selected) onFriendChanged;
  final VoidCallback onRetryFriends;
  final VoidCallback onClearSelectedFriends;
  final bool publicationFailed;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('check-in-page-4'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Semantics(
        label: AppStrings.checkInSummarySemantic,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  placeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(AppStrings.checkInSummaryType(typeName)),
                Text(AppStrings.checkInSummaryFlavors(flavorNames.join(', '))),
                Text(AppStrings.checkInSummaryRating(rating)),
                Text(
                  selectedFriendNames.isEmpty
                      ? AppStrings.checkInFriendsNone
                      : AppStrings.checkInFriendsList(selectedFriendNames.join(', ')),
                ),
                if (reviewText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(reviewText),
                ],
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Icon(Icons.lock_outline_rounded, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        hasPrivatePhoto
                            ? AppStrings.checkInPhotoReady
                            : AppStrings.checkInPhotoToVerify,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        AppStrings.checkInShareWithFriends,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      friends.when(
        data: (profiles) => profiles.isEmpty
            ? const Text(AppStrings.checkInNoFriendsToAdd)
            : Column(
                children: <Widget>[
                  for (final profile in profiles)
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: selectedFriendIds.contains(profile.uid),
                        title: Text(profile.displayName),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: enabled
                            ? (selected) => onFriendChanged(
                                profile.uid,
                                selected ?? false,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LinearProgressIndicator(),
            SizedBox(height: 8),
            Text(AppStrings.checkInLoadingFriends),
          ],
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(AppStrings.checkInFriendsLoadError),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: enabled ? onRetryFriends : null,
                  child: const Text(AppStrings.checkInReloadFriends),
                ),
                if (selectedFriendIds.isNotEmpty)
                  TextButton(
                    onPressed: enabled ? onClearSelectedFriends : null,
                    child: const Text(AppStrings.checkInRemoveTag),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (publicationFailed) ...<Widget>[
        const SizedBox(height: 12),
        const Text(AppStrings.checkInDraftRetryNote),
      ],
      if (hasPrivatePhoto && photoBytes != null) ...<Widget>[
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showShareCheckInPreview(
            context,
            placeName: placeName,
            rating: rating,
            flavors: shareFlavors,
            photo: Image.memory(photoBytes!, fit: BoxFit.cover),
          ),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text(AppStrings.checkInShareCardCta),
        ),
      ],
    ],
  );
}
