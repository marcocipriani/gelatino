import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flavor.dart';
import '../models/user_profile.dart';
import '../providers/flavors_provider.dart';
import '../providers/profile_providers.dart';
import '../repositories/profile_repository.dart';
import '../design/app_tokens.dart';
import '../design/focus_ring.dart';
import '../design/motion.dart';
import '../utils/search_text.dart';
import '../utils/error_handler.dart';
import 'app_controls.dart';
import 'app_search_field.dart';
import 'creamy_card.dart';
import 'report_button.dart';
import 'gelato_loader.dart';
import '../constants/app_strings.dart';

/// Full flavor manager: shared catalog with colored pills, per-user favorites,
/// add-with-color, search, A-Z / favorites-first sort, and a favorites filter.
/// Non-scrolling Column — the host screen provides the scroll view.
class FlavorsManager extends ConsumerStatefulWidget {
  const FlavorsManager({super.key});

  @override
  ConsumerState<FlavorsManager> createState() => _FlavorsManagerState();
}

class _FlavorsManagerState extends ConsumerState<FlavorsManager> {
  String _search = '';
  String _sort = 'az'; // 'az' | 'favorites'
  bool _onlyFavorites = false;
  bool _adding = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  late String _newColor = _palette.first;

  static const List<String> _palette = [
    '#EFE9DC',
    '#F4D58D',
    '#9CAF5A',
    '#B07D52',
    '#6F4E37',
    '#3E2723',
    '#FF4D6D',
    '#E0245E',
    '#9B1B30',
    '#4F5BD5',
    '#FFE34D',
    '#FF8C1A',
    '#FFB42E',
    '#3EB489',
    '#00BFFF',
    '#C8A2C8',
    '#C8852B',
    '#222222',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Color _hex(String? h) {
    if (h == null || h.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    var s = h.replaceFirst('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v == null ? Theme.of(context).colorScheme.primary : Color(v);
  }

  Future<void> _addFlavor() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _adding = true);
    try {
      final flavor = await ref
          .read(flavorServiceProvider)
          .addFlavor(name, colorHex: _newColor);
      // New flavors created by the user are marked favorite right away.
      final profile = ref.read(ownProfileProvider).value;
      if (profile != null) {
        final fav = List<String>.from(profile.favoriteFlavorIds)
          ..add(flavor.id);
        await ref
            .read(profileRepositoryProvider)
            .updateProfile(profile.uid, ProfilePatch(favoriteFlavorIds: fav));
      }
      _newCtrl.clear();
    } catch (e) {
      if (mounted) ErrorHandler.showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleFavorite(UserProfile profile, String flavorId) async {
    final fav = List<String>.from(profile.favoriteFlavorIds);
    fav.contains(flavorId) ? fav.remove(flavorId) : fav.add(flavorId);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(profile.uid, ProfilePatch(favoriteFlavorIds: fav));
    } catch (e) {
      if (mounted) ErrorHandler.showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flavorsAsync = ref.watch(flavorsProvider);
    final profile = ref.watch(ownProfileProvider).value;

    return flavorsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: GelatoLoader()),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 40,
                color: Theme.of(context).colorScheme.accentInk,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ErrorHandler.getReadableError(err),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => ref.invalidate(flavorsProvider),
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
      data: (flavors) {
        final favIds = profile?.favoriteFlavorIds.toSet() ?? <String>{};

        final query = normalizeSearchText(_search);
        var list = flavors.where((f) {
          if (!normalizeSearchText(f.name).contains(query)) {
            return false;
          }
          if (_onlyFavorites && !favIds.contains(f.id)) return false;
          return true;
        }).toList();

        list.sort((a, b) {
          if (_sort == 'favorites') {
            final favoriteOrder = (favIds.contains(b.id) ? 1 : 0).compareTo(
              favIds.contains(a.id) ? 1 : 0,
            );
            if (favoriteOrder != 0) return favoriteOrder;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddRow(context),
            const SizedBox(height: 12),
            _buildSearch(context),
            const SizedBox(height: 12),
            _buildControls(context),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _onlyFavorites
                        ? AppStrings.flavorNoFavorites
                        : AppStrings.flavorNoneFound,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final f in list)
                    _buildFlavorPill(
                      context,
                      f,
                      favIds.contains(f.id),
                      profile,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildFlavorPill(
    BuildContext context,
    Flavor flavor,
    bool isFav,
    UserProfile? profile,
  ) {
    final bg = _hex(flavor.colorHex);
    final fg = inkOn(bg);
    final colors = Theme.of(context).colorScheme;
    final onTap = profile == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            _toggleFavorite(profile, flavor.id);
          };
    return Semantics(
      button: true,
      selected: isFav,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: AppStrings.reportTooltip): () =>
            showReportSheet(context, ref, ReportTarget.flavor, flavor.id),
      },
      enabled: onTap != null,
      child: AppFocusRing(
        borderRadius: AppRadii.pill,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          onLongPress: () =>
              showReportSheet(context, ref, ReportTarget.flavor, flavor.id),
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.standard),
            curve: AppMotion.glide,
            constraints: const BoxConstraints(minHeight: AppLayout.touchTarget),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: isFav ? colors.onSurface : colors.outlineVariant,
                width: isFav ? 2.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFav ? CupertinoIcons.star_fill : CupertinoIcons.star,
                  size: 17,
                  color: fg,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    flavor.name,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) => AppSearchField(
    controller: _searchCtrl,
    hint: AppStrings.flavorSearchHint,
    onChanged: (value) => setState(() => _search = value),
  );

  Widget _buildControls(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSegmented<String>(
        value: _sort,
        onChanged: (value) => setState(() => _sort = value),
        segments: {
          'az': AppStrings.flavorSortAZ,
          'favorites': AppStrings.flavorSortFavorites,
        },
      ),
      const SizedBox(height: AppSpacing.xs),
      FilterChip(
        label: Text(AppStrings.flavorFavorites),
        showCheckmark: false,
        avatar: Icon(
          _onlyFavorites ? CupertinoIcons.star_fill : CupertinoIcons.star,
          size: 18,
          color: _onlyFavorites
              ? AppColors.fondente
              : Theme.of(context).colorScheme.onSurface,
        ),
        selected: _onlyFavorites,
        onSelected: (value) => setState(() => _onlyFavorites = value),
      ),
    ],
  );

  Widget _buildAddRow(BuildContext context) {
    return CreamyCard(
      borderRadius: 16,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCtrl,
                  decoration: InputDecoration(
                    hintText: AppStrings.flavorCreateHint,
                    hintMaxLines: 1,
                  ),
                  onSubmitted: (_) => _addFlavor(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: AppStrings.flavorCreateTooltip,
                onPressed: _adding ? null : _addFlavor,
                icon: _adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: GelatoLoader(size: 16),
                      )
                    : const Icon(CupertinoIcons.plus),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: AppLayout.touchTarget,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _palette.length,
              itemBuilder: (context, i) {
                final color = _hex(_palette[i]);
                final selected = _palette[i] == _newColor;
                final colors = Theme.of(context).colorScheme;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: AppStrings.flavorColorSemantic(i + 1, _palette.length),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _newColor = _palette[i]),
                    child: SizedBox.square(
                      dimension: AppLayout.touchTarget,
                      child: Center(
                        child: AnimatedContainer(
                          duration: AppMotion.of(context, AppMotion.fast),
                          width: selected ? 38 : 30,
                          height: selected ? 38 : 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? colors.onSurface
                                  : colors.outline,
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: selected
                              ? Icon(
                                  CupertinoIcons.check_mark,
                                  size: 16,
                                  color: inkOn(color),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Callback-driven flavor picker used by focused flows such as Check-in.
/// It owns only transient search/create UI; selection remains in the caller.
final class FlavorSelectionField extends StatefulWidget {
  const FlavorSelectionField({
    required this.flavors,
    required this.selectedIds,
    required this.onChanged,
    required this.onCreate,
    required this.onLimitReached,
    this.enabled = true,
    this.minimum = 1,
    this.maximum = 4,
    super.key,
  });

  final List<Flavor> flavors;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final Future<Flavor> Function(String name) onCreate;
  final VoidCallback onLimitReached;
  final bool enabled;
  final int minimum;
  final int maximum;

  @override
  State<FlavorSelectionField> createState() => _FlavorSelectionFieldState();
}

final class _FlavorSelectionFieldState extends State<FlavorSelectionField> {
  final _searchController = TextEditingController();
  final _newController = TextEditingController();
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _newController.text.trim();
    if (name.isEmpty || _creating || !widget.enabled) return;
    if (widget.selectedIds.length >= widget.maximum) {
      widget.onLimitReached();
      return;
    }
    setState(() => _creating = true);
    try {
      final flavor = await widget.onCreate(name);
      if (!mounted) return;
      if (!widget.selectedIds.contains(flavor.id)) {
        widget.onChanged(<String>[...widget.selectedIds, flavor.id]);
      }
      _newController.clear();
      _searchController.clear();
      setState(() => _query = '');
    } catch (_) {
      // The owner renders the domain failure; the control remains retryable.
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _toggle(Flavor flavor) {
    if (!widget.enabled) return;
    final selected = widget.selectedIds.contains(flavor.id);
    if (selected) {
      widget.onChanged(
        widget.selectedIds.where((id) => id != flavor.id).toList(),
      );
      return;
    }
    if (widget.selectedIds.length >= widget.maximum) {
      widget.onLimitReached();
      return;
    }
    widget.onChanged(<String>[...widget.selectedIds, flavor.id]);
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        widget.flavors
            .where(
              (flavor) => normalizeSearchText(
                flavor.name,
              ).contains(normalizeSearchText(_query)),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final byId = <String, Flavor>{
      for (final flavor in widget.flavors) flavor.id: flavor,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.flavorsCountRange(widget.minimum, widget.maximum),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (widget.selectedIds.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final id in widget.selectedIds)
                InputChip(
                  label: Text(byId[id]?.name ?? AppStrings.flavorSaved),
                  onDeleted: widget.enabled
                      ? () => widget.onChanged(
                          widget.selectedIds
                              .where((candidate) => candidate != id)
                              .toList(),
                        )
                      : null,
                ),
            ],
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: AppStrings.flavorSearchLabel,
            prefixIcon: Icon(CupertinoIcons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          Text(AppStrings.flavorNoneFound)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final flavor in visible)
                ChoiceChip(
                  key: ValueKey<String>('check-in-flavor-${flavor.id}'),
                  label: Text(flavor.name),
                  showCheckmark: true,
                  avatar: switch (flavor.color) {
                    final color? when !widget.selectedIds.contains(flavor.id) =>
                      CircleAvatar(backgroundColor: color),
                    _ => null,
                  },
                  selected: widget.selectedIds.contains(flavor.id),
                  onSelected: widget.enabled ? (_) => _toggle(flavor) : null,
                ),
            ],
          ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _newController,
                enabled: widget.enabled && !_creating,
                decoration: InputDecoration(
                  labelText: AppStrings.flavorNewLabel,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _create(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 48,
              child: IconButton.filled(
                tooltip: AppStrings.flavorCreateTooltip,
                onPressed: widget.enabled && !_creating ? _create : null,
                icon: _creating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CupertinoIcons.plus),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
