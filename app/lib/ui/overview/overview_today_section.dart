import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:spendwise/ledger/analysis/summaries/today_summary.dart';
import 'package:spendwise/ui/common/buttons/app_buttons.dart';
import 'package:spendwise/ui/common/feedback/loading_skeleton.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_constants.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

final _wholeDollarsSuffix = RegExp(r'\.00$');

// MARK: - Helpers

String _wholeWhenExact(Decimal amount) =>
    formatMoney(amount).replaceFirst(_wholeDollarsSuffix, '');

// MARK: - Tray

class TodayTray extends StatelessWidget {
  const TodayTray({
    super.key,
    required this.viewState,
    required this.viewModel,
  });

  final OverviewViewState viewState;
  final OverviewViewModel viewModel;

  static const _padding = 14.0;
  static const _borderWidth = 1.0;
  static const _largeRadius = 20.0;
  static const _cornerRadius = 7.0;
  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(_largeRadius),
    topRight: Radius.circular(_largeRadius),
    bottomLeft: Radius.circular(_largeRadius),
    bottomRight: Radius.circular(_cornerRadius),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final today = viewState.today;
    final Widget content;
    if (viewState.todayFailed) {
      content = TodayLoadError(viewModel: viewModel);
    } else if (today == null) {
      content = const LoadingSkeleton();
    } else {
      content = TodayContent(
        day: viewState.day,
        summary: today,
        recorded: viewState.recordedToday,
      );
    }
    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: isLight ? colors.surface : colors.tint,
        border: Border.all(
          color: isLight ? colors.edge : colors.tint,
          width: _borderWidth,
        ),
        borderRadius: _radius,
      ),
      child: SizedBox(width: overviewFullWidth, child: content),
    );
  }
}

// MARK: - Error

class TodayLoadError extends StatelessWidget {
  const TodayLoadError({super.key, required this.viewModel});

  final OverviewViewModel viewModel;

  static const _messageGap = 10.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overviewTodayErrorTitle,
          style: TextStyle(
            fontSize: overviewBodyFontSize,
            fontWeight: overviewSemiBold,
            color: context.colors.error,
          ),
        ),
        const SizedBox(height: _messageGap),
        PrimaryButton(
          label: overviewRetryLabel,
          onPressed: viewModel.retryToday,
        ),
      ],
    );
  }
}

// MARK: - Content

class TodayContent extends StatelessWidget {
  const TodayContent({
    super.key,
    required this.day,
    required this.summary,
    required this.recorded,
  });

  final DateTime day;
  final TodaySummary summary;
  final bool recorded;

  static const _heroVerticalGap = 4.0;
  static const _heroBottomGap = 6.0;
  static const _midFontSize = 18.0;
  static const _midLetterSpacing = -0.3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = TextStyle(
      fontSize: overviewSmallFontSize,
      color: colors.subtext,
    );
    final headline = recorded
        ? Text(formatMoney(summary.spent), style: context.text.hero)
        : Text(
            overviewNothingToday,
            style: context.text.headline.copyWith(
              fontSize: _midFontSize,
              letterSpacing: _midLetterSpacing,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$overviewTodayCaption${formatDayMonthLong(day)}', style: label),
        const SizedBox(height: _heroVerticalGap),
        headline,
        const SizedBox(height: _heroBottomGap),
        DailyGuide(summary: summary, label: label),
      ],
    );
  }
}

// MARK: - Guide

class DailyGuide extends StatelessWidget {
  const DailyGuide({super.key, required this.summary, required this.label});

  final TodaySummary summary;
  final TextStyle label;

  @override
  Widget build(BuildContext context) {
    final guide = summary.dailyGuide;
    final cap = summary.monthlyCap;
    if (guide == null || cap == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(overviewNoCapCaption, style: label),
          const _GuideLinkText(overviewNoCapLink),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$overviewGuideLabel${_wholeWhenExact(guide)}',
          style: const TextStyle(
            fontSize: overviewBodyFontSize,
            fontWeight: overviewSemiBold,
          ),
        ),
        Text(
          '$overviewCapCaptionPrefix${_wholeWhenExact(cap)}$overviewCapCaptionSuffix',
          style: label,
        ),
      ],
    );
  }
}

class _GuideLinkText extends StatelessWidget {
  const _GuideLinkText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.action;
    return Padding(
      padding: const EdgeInsets.only(top: overviewLinkTopPadding),
      child: Text(
        text,
        style: TextStyle(
          fontSize: overviewBodyFontSize,
          fontWeight: overviewSemiBold,
          color: color,
        ),
      ),
    );
  }
}
