import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_slots.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

class OverviewSlotColumn extends ConsumerWidget {
  const OverviewSlotColumn({
    super.key,
    required this.viewState,
    required this.viewModel,
  });

  final OverviewViewState viewState;
  final OverviewViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kinds = ref.watch(
      displayPreferencesProvider.select(
        (preferences) => preferences.overviewWidgets,
      ),
    );
    final slots = <Widget>[];
    for (final kind in kinds) {
      if (overviewSlotFor(kind, viewState: viewState, viewModel: viewModel)
          case final slot?) {
        slots.add(KeyedSubtree(key: ValueKey(kind), child: slot));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: overviewTrayGap,
      children: slots,
    );
  }
}
