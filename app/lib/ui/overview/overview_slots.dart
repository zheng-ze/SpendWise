import 'package:flutter/material.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_coming_up_section.dart';
import 'package:spendwise/ui/overview/overview_recent_section.dart';
import 'package:spendwise/ui/overview/overview_today_section.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

Widget? overviewSlotFor(
  OverviewWidgetKind kind, {
  required OverviewViewState viewState,
  required OverviewViewModel viewModel,
}) => switch (kind) {
  OverviewWidgetKind.today => TodayTray(
    viewState: viewState,
    viewModel: viewModel,
  ),
  OverviewWidgetKind.recentEntries => RecentTray(
    rows: viewState.recent,
    viewModel: viewModel,
  ),
  OverviewWidgetKind.comingUp => ComingUpTray(rows: viewState.upcoming),
  OverviewWidgetKind.thisMonth ||
  OverviewWidgetKind.topCategories ||
  OverviewWidgetKind.cardStatement ||
  OverviewWidgetKind.accountBalances ||
  OverviewWidgetKind.spendingOverTime ||
  OverviewWidgetKind.savingsPocket ||
  OverviewWidgetKind.budgetWatch ||
  OverviewWidgetKind.insights ||
  OverviewWidgetKind.weekSoFar => null,
};
