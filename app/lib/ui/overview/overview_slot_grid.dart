import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_grid_placement.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';
import 'package:spendwise/ui/overview/overview_waterfall_layout.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

class OverviewSlotGrid extends ConsumerWidget {
  const OverviewSlotGrid({
    super.key,
    required this.layoutMode,
    required this.presentation,
    required this.viewState,
    required this.viewModel,
  });

  final ShellLayoutMode layoutMode;
  final ShellPagePresentation presentation;
  final OverviewViewState viewState;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kinds = overviewWidgetsOrDefault(
      ref.watch(
        displayPreferencesProvider.select(
          (preferences) => preferences.overviewWidgets,
        ),
      ),
    );
    final slots = <OverviewWidgetKind, Widget>{};
    for (final kind in kinds) {
      if (overviewSlotFor(kind, viewState: viewState, viewModel: viewModel)
          case final slot?) {
        slots[kind] = slot;
      }
    }
    final windowWidth = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) => _OverviewSlotWaterfall(
        layoutMode: layoutMode,
        presentation: presentation,
        windowWidth: windowWidth,
        gridWidth: constraints.maxWidth,
        slots: slots,
      ),
    );
  }
}

class _OverviewSlotWaterfall extends StatelessWidget {
  const _OverviewSlotWaterfall({
    required this.layoutMode,
    required this.presentation,
    required this.windowWidth,
    required this.gridWidth,
    required this.slots,
  });

  final ShellLayoutMode layoutMode;
  final ShellPagePresentation presentation;
  final double windowWidth;
  final double gridWidth;
  final Map<OverviewWidgetKind, Widget> slots;

  @override
  Widget build(BuildContext context) {
    final columnCount = overviewColumnCount(
      mode: layoutMode,
      presentation: presentation,
      windowWidth: windowWidth,
      gridWidth: gridWidth,
    );
    final children = [
      for (final MapEntry(:key, :value) in slots.entries)
        OverviewWaterfallSlot(
          key: ValueKey(key),
          span: overviewColumnSpan(key),
          child: value,
        ),
    ];
    return OverviewWaterfall(
      columnCount: columnCount,
      gap: overviewTrayGap,
      children: children,
    );
  }
}
