import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_strings.dart';
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
      const Text(AppStrings.checkInRatingTitle, style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        children: <Widget>[
          for (var value = 1; value <= 5; value++)
            Semantics(
              key: ValueKey<String>('check-in-rating-$value'),
              selected: rating == value,
              label: AppStrings.checkInStarsSemantic(value, selected: rating == value),
              button: true,
              child: IconButton(
                tooltip: AppStrings.checkInStarsTooltip(value),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: enabled ? () => onRatingChanged(value) : null,
                icon: Icon(
                  value <= (rating ?? 0) ? Icons.star : Icons.star_border,
                  color: Theme.of(context).colorScheme.tertiary,
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
          border: OutlineInputBorder(),
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
              icon: const Icon(Icons.event_outlined),
              label: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  consumedAt == null
                      ? AppStrings.checkInWhenNow
                      : _format(consumedAt!),
                ),
              ),
            ),
          ),
          if (consumedAt != null)
            IconButton(
              key: const ValueKey<String>('check-in-consumed-at-reset'),
              tooltip: AppStrings.checkInWhenReset,
              onPressed: enabled ? () => onConsumedAtChanged(null) : null,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    ],
  );

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final current = consumedAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(CheckInDraft.maxBackdate),
      lastDate: now,
      helpText: AppStrings.checkInWhenPickDate,
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

  static String _format(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year} · '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
