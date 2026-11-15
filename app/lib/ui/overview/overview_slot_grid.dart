import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_grid_placement.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';
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
    final kinds = ref.watch(
      displayPreferencesProvider.select(
        (preferences) => preferences.overviewWidgets,
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
      builder: (context, constraints) => _OverviewSlotWrap(
        layoutMode: layoutMode,
        presentation: presentation,
        windowWidth: windowWidth,
        gridWidth: constraints.maxWidth,
        slots: slots,
      ),
    );
  }
}

class _OverviewSlotWrap extends StatelessWidget {
  const _OverviewSlotWrap({
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
    final cells = placeOverviewWidgets(
      slots.keys.toList(),
      columnCount: columnCount,
    );
    final columnWidth =
        (gridWidth - overviewTrayGap * (columnCount - 1)) / columnCount;
    final children = [
      for (final cell in cells)
        KeyedSubtree(
          key: ValueKey(cell.kind),
          child: SizedBox(
            width: columnWidth * cell.span + overviewTrayGap * (cell.span - 1),
            child: slots[cell.kind],
          ),
        ),
    ];
    return Wrap(
      spacing: overviewTrayGap,
      runSpacing: overviewTrayGap,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: children,
    );
  }
}
