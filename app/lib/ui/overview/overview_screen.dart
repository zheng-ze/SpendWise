import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/overview/overview_coming_up_section.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_recent_section.dart';
import 'package:spendwise/ui/overview/overview_today_section.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Screen

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({
    super.key,
    this.layoutMode = ShellLayoutMode.phone,
    this.presentation = ShellPagePresentation.fullPage,
  });

  final ShellLayoutMode layoutMode;
  final ShellPagePresentation presentation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(overviewViewModelProvider).value;
    final viewModel = ref.watch(overviewViewModelProvider.notifier);
    if (viewState == null) {
      return const Scaffold(body: LoadingSkeleton());
    }
    final today = TodayTray(viewState: viewState, viewModel: viewModel);
    final recent = RecentTray(rows: viewState.recent, viewModel: viewModel);
    final comingUp = ComingUpTray(rows: viewState.upcoming);
    final sections =
        layoutMode == ShellLayoutMode.open &&
            presentation == ShellPagePresentation.fullPage
        ? _OpenOverviewGrid(today: today, recent: recent, comingUp: comingUp)
        : _OverviewSections(today: today, recent: recent, comingUp: comingUp);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: overviewPagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverviewHeader(day: viewState.day),
              sections,
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewSections extends StatelessWidget {
  const _OverviewSections({
    required this.today,
    required this.recent,
    required this.comingUp,
  });

  final Widget today;
  final Widget recent;
  final Widget comingUp;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      today,
      const SizedBox(height: overviewTrayGap),
      recent,
      const SizedBox(height: overviewTrayGap),
      comingUp,
    ],
  );
}

class _OpenOverviewGrid extends StatelessWidget {
  const _OpenOverviewGrid({
    required this.today,
    required this.recent,
    required this.comingUp,
  });

  final Widget today;
  final Widget recent;
  final Widget comingUp;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columnWidth =
          (constraints.maxWidth - overviewTrayGap * overviewGridGapCount) /
          overviewGridColumnCount;
      if (columnWidth < overviewGridMinimumColumnWidth) {
        return _OverviewSections(
          today: today,
          recent: recent,
          comingUp: comingUp,
        );
      }
      final spanWidth =
          columnWidth * overviewGridSpanColumnCount + overviewTrayGap;
      final todayRow = Row(
        children: [
          SizedBox(width: spanWidth, child: today),
          const SizedBox(width: overviewTrayGap),
          SizedBox(width: columnWidth),
        ],
      );
      final recentAndComingRow = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: spanWidth, child: recent),
            const SizedBox(width: overviewTrayGap),
            SizedBox(width: columnWidth, child: comingUp),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          todayRow,
          const SizedBox(height: overviewTrayGap),
          recentAndComingRow,
        ],
      );
    },
  );
}

// MARK: - Header

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.day});

  final DateTime day;

  static const _bottomPadding = 14.0;
  static const _dateGap = 2.0;
  static const _titleFontSize = 26.0;
  static const _titleLineHeight = 1.12;
  static const _titleLetterSpacing = -0.7;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: _bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatWeekdayDate(day),
            style: TextStyle(
              fontSize: overviewSmallFontSize,
              color: colors.subtext,
            ),
          ),
          const SizedBox(height: _dateGap),
          const Text(
            overviewTitle,
            style: TextStyle(
              fontSize: _titleFontSize,
              fontWeight: overviewSemiBold,
              height: _titleLineHeight,
              letterSpacing: _titleLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}
