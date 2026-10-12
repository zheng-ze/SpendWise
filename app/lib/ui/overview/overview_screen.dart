import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/loading_skeleton.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/overview/overview_coming_up_section.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_recent_section.dart';
import 'package:spendwise/ui/overview/overview_today_section.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

// MARK: - Screen

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(overviewViewModelProvider).value;
    final viewModel = ref.watch(overviewViewModelProvider.notifier);
    if (viewState == null) {
      return const Scaffold(body: LoadingSkeleton());
    }
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: overviewPagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverviewHeader(day: viewState.day),
              TodayTray(viewState: viewState, viewModel: viewModel),
              const SizedBox(height: overviewTrayGap),
              RecentTray(rows: viewState.recent, viewModel: viewModel),
              const SizedBox(height: overviewTrayGap),
              ComingUpTray(rows: viewState.upcoming),
            ],
          ),
        ),
      ),
    );
  }
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
