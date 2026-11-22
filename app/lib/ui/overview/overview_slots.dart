import 'package:flutter/material.dart';

import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/ui/overview/overview_coming_up_section.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_recent_section.dart';
import 'package:spendwise/ui/overview/overview_this_month_section.dart';
import 'package:spendwise/ui/overview/overview_today_section.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';

typedef OverviewSlotBuilder = Widget Function(
  OverviewViewState viewState,
  OverviewViewModel viewModel,
);

class OverviewCard {
  const OverviewCard({
    required this.title,
    required this.subtitle,
    required this.build,
  });

  final String title;
  final String subtitle;
  final OverviewSlotBuilder build;
}

OverviewCard? overviewCardFor(OverviewWidgetKind kind) => switch (kind) {
  OverviewWidgetKind.today => OverviewCard(
    title: overviewTodayTitle,
    subtitle: overviewTodaySubtitle,
    build: (viewState, viewModel) =>
        TodayTray(viewState: viewState, viewModel: viewModel),
  ),
  OverviewWidgetKind.recentEntries => OverviewCard(
    title: overviewRecentTitle,
    subtitle: overviewRecentSubtitle,
    build: (viewState, viewModel) =>
        RecentTray(rows: viewState.recent, viewModel: viewModel),
  ),
  OverviewWidgetKind.comingUp => OverviewCard(
    title: overviewComingUpTitle,
    subtitle: overviewComingUpSubtitle,
    build: (viewState, viewModel) => ComingUpTray(rows: viewState.upcoming),
  ),
  OverviewWidgetKind.thisMonth => OverviewCard(
    title: overviewThisMonthTitle,
    subtitle: overviewThisMonthSubtitle,
    build: (viewState, viewModel) => ThisMonthTray(
      month: viewState.thisMonth,
      failed: viewState.thisMonthFailed,
      onRetry: viewModel.retryReads,
    ),
  ),
  OverviewWidgetKind.topCategories ||
  OverviewWidgetKind.cardStatement ||
  OverviewWidgetKind.accountBalances ||
  OverviewWidgetKind.spendingOverTime ||
  OverviewWidgetKind.savingsPocket ||
  OverviewWidgetKind.budgetWatch ||
  OverviewWidgetKind.insights ||
  OverviewWidgetKind.weekSoFar => null,
};

Widget? overviewSlotFor(
  OverviewWidgetKind kind, {
  required OverviewViewState viewState,
  required OverviewViewModel viewModel,
}) => overviewCardFor(kind)?.build(viewState, viewModel);

final overviewCardKinds = [
  for (final kind in OverviewWidgetKind.values)
    if (overviewCardFor(kind) != null) kind,
];

List<OverviewWidgetKind> overviewWidgetsOrDefault(
  List<OverviewWidgetKind> stored,
) {
  final hasCard = stored.any(overviewCardKinds.contains);
  return hasCard ? stored : DisplayPreferences.defaults.overviewWidgets;
}
