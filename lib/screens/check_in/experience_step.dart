import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_strings.dart';
import '../../design/app_tokens.dart';
import '../../design/motion.dart';
import '../../models/check_in_draft.dart';

final class ExperienceStep extends StatelessWidget {
  const ExperienceStep({
    required this.rating,
    required this.reviewController,
    required this.enabled,
    required this.onRatingChanged,
    required this.onReviewChanged,
    required this.consumedAt,
    required this.onConsumedAtChanged,
    super.key,
  });

  final int? rating;
  final TextEditingController reviewController;
  final bool enabled;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String> onReviewChanged;

  /// Null means "now", which is what almost every check-in is. Only a
  /// backdated one carries a value.
  final DateTime? consumedAt;
  final ValueChanged<DateTime?> onConsumedAtChanged;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('check-in-page-3'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Text(
        AppStrings.checkInRatingTitle,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        children: <Widget>[
          for (var value = 1; value <= 5; value++)
            Semantics(
              key: ValueKey<String>('check-in-rating-$value'),
              selected: rating == value,
              label: AppStrings.checkInStarsSemantic(
                value,
                selected: rating == value,
              ),
              button: true,
              child: IconButton(
                tooltip: AppStrings.checkInStarsTooltip(value),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: enabled
                    ? () {
                        HapticFeedback.selectionClick();
                        onRatingChanged(value);
                      }
                    : null,
                icon: AnimatedScale(
                  scale: value <= (rating ?? 0) ? 1 : 0.86,
                  duration: AppMotion.of(context, AppMotion.standard),
                  curve: AppMotion.glide,
                  child: Icon(
                    value <= (rating ?? 0)
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    size: 34,
                    color: value <= (rating ?? 0)
                        ? Theme.of(context).colorScheme.accentInk
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: reviewController,
        enabled: enabled,
        maxLength: 500,
        maxLines: 5,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(500),
        ],
        decoration: const InputDecoration(
          labelText: AppStrings.checkInNoteLabel,
          alignLabelWithHint: true,
        ),
        onChanged: onReviewChanged,
      ),
      const SizedBox(height: 16),
      const Text(
        AppStrings.checkInWhenTitle,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey<String>('check-in-consumed-at'),
              onPressed: enabled ? () => _pick(context) : null,
              icon: const Icon(CupertinoIcons.calendar),
              label: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  consumedAt == null
                      ? AppStrings.checkInWhenNow
                      : _format(consumedAt!.toLocal()),
                ),
              ),
            ),
          ),
          if (consumedAt != null)
            IconButton(
              key: const ValueKey<String>('check-in-consumed-at-reset'),
              tooltip: AppStrings.checkInWhenReset,
              onPressed: enabled ? () => onConsumedAtChanged(null) : null,
              icon: const Icon(CupertinoIcons.xmark),
            ),
        ],
      ),
    ],
  );

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    // The draft stores UTC; people pick and read wall-clock time.
    final current = consumedAt?.toLocal() ?? now;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _pickWithWheels(context, current: current, now: now);
    }
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(CheckInDraft.maxBackdate),
      lastDate: now,
      helpText: AppStrings.checkInWhenPickDate,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final size = media.size;
        // The sideways layout squeezes days to 35pt. Upright needs 568 plus
        // insets, so use it wherever that fits.
        if (size.width <= size.height || size.height < 620) return child!;
        return MediaQuery(
          data: media.copyWith(size: Size(size.height - 1, size.height)),
          child: child!,
        );
      },
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // The date picker is capped at today, but its time half is not: picking
    // today plus a later hour would still land in the future.
    onConsumedAtChanged(picked.isAfter(DateTime.now()) ? null : picked);
  }

  Future<void> _pickWithWheels(
    BuildContext context, {
    required DateTime current,
    required DateTime now,
  }) async {
    var picked = current.isAfter(now) ? now : current;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('check-in-consumed-at-done'),
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text(AppStrings.done),
                ),
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  initialDateTime: picked,
                  // A day inside the limit the draft re-checks when published.
                  minimumDate: now.subtract(
                    CheckInDraft.maxBackdate - const Duration(days: 1),
                  ),
                  maximumDate: now,
                  use24hFormat: true,
                  onDateTimeChanged: (value) => picked = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    // Left on "now" means now, not a backdate.
    onConsumedAtChanged(picked.isBefore(now) ? picked : null);
  }

  static String _format(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year} · '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
