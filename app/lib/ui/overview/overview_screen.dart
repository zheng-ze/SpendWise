import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ledger/analysis/today_summary.dart';
import 'package:spendwise/ui/common/app_buttons.dart';
import 'package:spendwise/ui/common/loading_skeleton.dart';
import 'package:spendwise/ui/common/medallion_row.dart';
import 'package:spendwise/ui/common/tray.dart';
import 'package:spendwise/ui/format/amount_style.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _fullWidth = double.infinity;
const _linkChevron = Icons.chevron_right;
const _statementSymbol = 'credit_card';
const _todayErrorTitle = "Couldn't load today's spending";
const _retryLabel = 'Retry';
const _pagePadding = EdgeInsets.fromLTRB(14, 12, 14, 14);
const _trayGap = 10.0;
const _smallFontSize = 10.0;
const _bodyFontSize = 12.0;
const _semiBold = FontWeight.w600;
const _rowVerticalPadding = 7.0;
const _rowDividerWidth = 1.0;
const _rowTrailingGap = 9.0;
const _linkIconSize = 14.0;
const _linkTopPadding = 8.0;
const _title = 'Overview';
const _recentTitle = 'Recent entries';
const _recentEmpty = 'Your entries will appear here.';
const _historyLink = 'View History';
const _comingUpTitle = 'Coming up';
const _comingUpWindow = 'Next 6 weeks';
const _comingUpEmpty = 'No known dates in the next six weeks.';
const _todayCaption = 'Today / ';
const _nothingToday = 'Nothing recorded today';
const _guideLabel = 'Daily guide: about ';
const _capCaptionPrefix = 'From your ';
const _capCaptionSuffix = ' monthly cap.';
const _noCapCaption = 'Set a monthly cap to see a daily guide.';
const _noCapLink = 'Set a monthly cap';
final _wholeDollarsSuffix = RegExp(r'\.00$');

String _wholeWhenExact(Decimal amount) =>
    formatMoney(amount).replaceFirst(_wholeDollarsSuffix, '');

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(overviewViewModelProvider);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: _pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverviewHeader(day: viewState.day),
              _TodayTray(viewState: viewState),
              const SizedBox(height: _trayGap),
              _RecentTray(rows: viewState.recent),
              const SizedBox(height: _trayGap),
              _ComingUpTray(rows: viewState.upcoming),
            ],
          ),
        ),
      ),
    );
  }
}

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
            style: TextStyle(fontSize: _smallFontSize, color: colors.subtext),
          ),
          const SizedBox(height: _dateGap),
          const Text(
            _title,
            style: TextStyle(
              fontSize: _titleFontSize,
              fontWeight: _semiBold,
              height: _titleLineHeight,
              letterSpacing: _titleLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayTray extends StatelessWidget {
  const _TodayTray({required this.viewState});

  final OverviewViewState viewState;

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
      content = const _TodayError();
    } else if (today == null) {
      content = const LoadingSkeleton();
    } else {
      content = _TodayContent(
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
      child: SizedBox(width: _fullWidth, child: content),
    );
  }
}

class _TodayError extends ConsumerWidget {
  const _TodayError();

  static const _messageGap = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _todayErrorTitle,
          style: TextStyle(
            fontSize: _bodyFontSize,
            fontWeight: _semiBold,
            color: context.colors.error,
          ),
        ),
        const SizedBox(height: _messageGap),
        PrimaryButton(
          label: _retryLabel,
          onPressed: ref.read(overviewViewModelProvider.notifier).retryToday,
        ),
      ],
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({
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
    final label = TextStyle(fontSize: _smallFontSize, color: colors.subtext);
    final headline = recorded
        ? Text(formatMoney(summary.spent), style: context.text.hero)
        : Text(
            _nothingToday,
            style: context.text.headline.copyWith(
              fontSize: _midFontSize,
              letterSpacing: _midLetterSpacing,
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_todayCaption${formatDayMonthLong(day)}', style: label),
        const SizedBox(height: _heroVerticalGap),
        headline,
        const SizedBox(height: _heroBottomGap),
        _DailyGuide(summary: summary, label: label),
      ],
    );
  }
}

class _DailyGuide extends StatelessWidget {
  const _DailyGuide({required this.summary, required this.label});

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
          Text(_noCapCaption, style: label),
          const _LinkText(_noCapLink),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_guideLabel${_wholeWhenExact(guide)}',
          style: const TextStyle(
            fontSize: _bodyFontSize,
            fontWeight: _semiBold,
          ),
        ),
        Text(
          '$_capCaptionPrefix${_wholeWhenExact(cap)}$_capCaptionSuffix',
          style: label,
        ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.text, {this.withChevron = false});

  final String text;
  final bool withChevron;

  static const _chevronGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.action;
    return Padding(
      padding: const EdgeInsets.only(top: _linkTopPadding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: _semiBold,
              color: color,
            ),
          ),
          if (withChevron) ...[
            const SizedBox(width: _chevronGap),
            Icon(_linkChevron, size: _linkIconSize, color: color),
          ],
        ],
      ),
    );
  }
}

class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: _smallFontSize, color: context.colors.subtext),
  );
}

class _RecentTray extends StatelessWidget {
  const _RecentTray({required this.rows});

  final List<OverviewEntryRow>? rows;

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    final Widget content;
    if (rows == null) {
      content = const LoadingSkeleton();
    } else if (rows.isEmpty) {
      content = const _EmptyCopy(_recentEmpty);
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, row) in rows.indexed)
            _OverviewRowFrame(
              isLast: index == rows.length - 1,
              child: _EntryRowContent(row: row),
            ),
          const _LinkText(_historyLink, withChevron: true),
        ],
      );
    }
    return SizedBox(
      width: _fullWidth,
      child: Tray(title: _recentTitle, child: content),
    );
  }
}

class _ComingUpTray extends StatelessWidget {
  const _ComingUpTray({required this.rows});

  final List<OverviewUpcomingRow>? rows;

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    final Widget content;
    if (rows == null) {
      content = const LoadingSkeleton();
    } else if (rows.isEmpty) {
      content = const _EmptyCopy(_comingUpEmpty);
    } else {
      content = Column(
        children: [
          for (final (index, row) in rows.indexed)
            _OverviewRowFrame(
              isLast: index == rows.length - 1,
              child: _UpcomingRowContent(row: row),
            ),
        ],
      );
    }
    return SizedBox(
      width: _fullWidth,
      child: Tray(
        title: _comingUpTitle,
        trailing: _EmptyCopy(_comingUpWindow),
        child: content,
      ),
    );
  }
}

class _OverviewRowFrame extends StatelessWidget {
  const _OverviewRowFrame({required this.isLast, required this.child});

  final bool isLast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(
      color: context.colors.edge,
      width: _rowDividerWidth,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: _rowVerticalPadding),
      decoration: isLast
          ? null
          : BoxDecoration(border: Border(bottom: divider)),
      child: child,
    );
  }
}

class _AmountText extends StatelessWidget {
  const _AmountText({required this.amount, required this.kind});

  final Decimal amount;
  final AmountKind kind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: _rowTrailingGap),
      child: Text(
        formatSignedMoney(amount, kind: kind, symbol: false),
        style: context.text.small.copyWith(
          color: AmountStyle.of(context, kind: kind).color,
        ),
      ),
    );
  }
}

class _EntryRowContent extends StatelessWidget {
  const _EntryRowContent({required this.row});

  final OverviewEntryRow row;

  @override
  Widget build(BuildContext context) {
    return MedallionRow(
      icon: symbolIcon(row.symbolName),
      iconColor: row.color,
      title: row.title,
      subtitle: row.caption,
      trailing: _AmountText(amount: row.amount, kind: row.amountKind),
    );
  }
}

class _UpcomingRowContent extends StatelessWidget {
  const _UpcomingRowContent({required this.row});

  final OverviewUpcomingRow row;

  static const _dateWidth = 30.0;
  static const _dayFontSize = 18.0;
  static const _dayLineHeight = 1.05;
  static const _statementIconSize = 17.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = row.amount;
    final kind = row.amountKind;
    final Widget trailing = amount == null || kind == null
        ? Padding(
            padding: const EdgeInsets.only(left: _rowTrailingGap),
            child: Icon(
              symbolIcon(_statementSymbol),
              size: _statementIconSize,
              color: colors.text,
            ),
          )
        : _AmountText(amount: amount, kind: kind);
    final date = SizedBox(
      width: _dateWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.day,
            style: const TextStyle(
              fontSize: _dayFontSize,
              fontWeight: _semiBold,
              height: _dayLineHeight,
            ),
          ),
          Text(
            row.month,
            style: TextStyle(
              fontSize: _smallFontSize,
              color: colors.subtext,
              height: _dayLineHeight,
            ),
          ),
        ],
      ),
    );
    return MedallionRow(
      leading: date,
      title: row.title,
      subtitle: row.caption,
      trailing: trailing,
    );
  }
}
