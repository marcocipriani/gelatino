import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/app_strings.dart';
import '../../design/app_tokens.dart';
import '../../services/share_service.dart';
import '../../theme/app_theme.dart';

/// Fixed-size (1080x1350, 3:4) branded card rendered for export/sharing.
/// Pure presentation: no service calls, no network/IO. Callers capture it
/// via [showShareCheckInPreview] (which wires in [shareCheckInCard]).
final class ShareCheckInCard extends StatelessWidget {
  const ShareCheckInCard({
    super.key,
    required this.placeName,
    required this.rating,
    required this.flavors,
    required this.photo,
  });

  final String placeName;
  final int rating;
  final List<Map<String, dynamic>> flavors;
  final Widget photo;

  static const double width = 1080;
  static const double height = 1350;

  @override
  Widget build(BuildContext context) {
    // OverflowBox forces the card to lay out at its true 1080x1350 design
    // size regardless of the ambient constraints (a plain SizedBox would get
    // clamped down by whatever host it's mounted in — e.g. the default test
    // surface — which breaks the fixed-pixel layout below). Callers control
    // the visible/captured size instead, via FittedBox + RepaintBoundary.
    return OverflowBox(
      minWidth: width,
      maxWidth: width,
      minHeight: height,
      maxHeight: height,
      alignment: Alignment.topLeft,
      child: ColoredBox(
        color: AppTheme.fiorDiPanna,
        child: Padding(
          padding: const EdgeInsets.all(56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 7,
                child: ClipSmoothRect(
                  radius: SmoothBorderRadius(
                    cornerRadius: 64,
                    cornerSmoothing: 0.6,
                  ),
                  child: SizedBox.expand(child: photo),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SvgPicture.asset(
                              'assets/images/simple-pin.svg',
                              width: 72,
                              height: 72,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  placeName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 44,
                                    color: AppTheme.fondenteExtra,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: List<Widget>.generate(
                            5,
                            (index) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.star_rounded,
                                size: 48,
                                color: index < rating
                                    ? AppTheme.sorbettoYuzu
                                    : AppTheme.fondenteExtra.withValues(
                                        alpha: 0.2,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: flavors
                              .map(
                                (flavor) => _FlavorChip(
                                  name: flavor['name'] as String,
                                  colorHex: flavor['color_hex'] as String?,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        'Gelatino',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                          color: AppTheme.fondenteExtra,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flavor pill colored by [colorHex] (mirrors the pill style in
/// `flavors_manager.dart`). A missing/unparseable hex (legacy check-ins)
/// falls back to a fixed Fondente tint — this card always renders in its
/// own fixed brand look, never the device's light/dark theme, so the
/// fallback uses the same token directly rather than an ambient
/// `colorScheme.onSurface` lookup.
final class _FlavorChip extends StatelessWidget {
  const _FlavorChip({required this.name, required this.colorHex});

  final String name;
  final String? colorHex;

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseHex(colorHex);
    final background = parsed ?? AppTheme.fondenteExtra.withValues(alpha: 0.1);
    final foreground = parsed == null
        ? AppTheme.fondenteExtra
        : (background.computeLuminance() > 0.55
              ? AppTheme.fondenteExtra
              : Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w700,
          fontSize: 28,
          color: foreground,
        ),
      ),
    );
  }
}

/// Opens a scaled preview of [ShareCheckInCard] with a 'Condividi' button.
/// Shared by both entry points (timeline card, check-in share step) so the
/// capture mechanics (RepaintBoundary + frame wait + [shareCheckInCard])
/// live in exactly one place.
///
/// The card is rendered at its native 1080x1350 size inside the
/// [RepaintBoundary] and only *displayed* scaled down via [FittedBox] — the
/// boundary's `toImage()` always captures its own native resolution
/// regardless of an ancestor's paint transform, so a separate invisible
/// full-size mount isn't needed.
Future<void> showShareCheckInPreview(
  BuildContext context, {
  required String placeName,
  required int rating,
  required List<Map<String, dynamic>> flavors,
  required Widget photo,
  ShareCardCallback onShare = shareCheckInCard,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _ShareCheckInPreviewDialog(
      placeName: placeName,
      rating: rating,
      flavors: flavors,
      photo: photo,
      onShare: onShare,
    ),
  );
}

/// Matches [shareCheckInCard]'s signature — overridable in tests to fake the
/// capture/share call without touching the real render pipeline or platform
/// share sheet.
typedef ShareCardCallback =
    Future<void> Function(GlobalKey repaintKey, {required String placeName});

final class _ShareCheckInPreviewDialog extends StatefulWidget {
  const _ShareCheckInPreviewDialog({
    required this.placeName,
    required this.rating,
    required this.flavors,
    required this.photo,
    required this.onShare,
  });

  final String placeName;
  final int rating;
  final List<Map<String, dynamic>> flavors;
  final Widget photo;
  final ShareCardCallback onShare;

  @override
  State<_ShareCheckInPreviewDialog> createState() =>
      _ShareCheckInPreviewDialogState();
}

final class _ShareCheckInPreviewDialogState
    extends State<_ShareCheckInPreviewDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.mediumImpact();
    try {
      // The dialog has already painted at least once by the time the user
      // can tap this button; waiting one more frame guards against the
      // photo widget still settling its final pixels (e.g. a decode that
      // completed between the last two frames).
      await WidgetsBinding.instance.endOfFrame;
      await widget.onShare(_repaintKey, placeName: widget.placeName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.shareCardFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenSize.width * 0.8,
                maxHeight: screenSize.height * 0.6,
              ),
              child: FittedBox(
                // FittedBox measures its child under unbounded constraints,
                // which the card's own OverflowBox can't size itself under
                // (it would try to be infinitely big). This SizedBox pins
                // the child to the card's exact design size first, so
                // OverflowBox only ever sees bounded constraints.
                child: SizedBox(
                  width: ShareCheckInCard.width,
                  height: ShareCheckInCard.height,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: ShareCheckInCard(
                      placeName: widget.placeName,
                      rating: widget.rating,
                      flavors: widget.flavors,
                      photo: widget.photo,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: _sharing
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(AppStrings.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sharing ? null : _share,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.fragolaPop,
                  ),
                  child: _sharing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(AppStrings.shareCardPreviewConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
