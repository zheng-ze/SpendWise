import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';

// MARK: - Constants
const _monthsPerYear = 12;
const _monthSpan = 12;
const _yearSpan = 3;
const _pagePrevious = -1;
const _pageNext = 1;
const _maximumDateTimeMilliseconds = 8640000000000000;
final _minimumDateTime = DateTime.fromMillisecondsSinceEpoch(
  -_maximumDateTimeMilliseconds,
  isUtc: true,
);
final _maximumDateTime = DateTime.fromMillisecondsSinceEpoch(
  _maximumDateTimeMilliseconds,
  isUtc: true,
);
final _minimumCompleteYear = _minimumDateTime.year + 1;
final _maximumCompleteYear = _maximumDateTime.year - 1;

// MARK: - Choices
enum TrendsKind { expense, income }

enum TrendsMode { month, year }

// MARK: - Calendar
int monthSerial(DateTime day) => day.year * _monthsPerYear + day.month - 1;

int _floorDivide(int value, int divisor) =>
    value >= 0 ? value ~/ divisor : -((-value + divisor - 1) ~/ divisor);

int _positiveModulo(int value, int divisor) =>
    ((value % divisor) + divisor) % divisor;

DateTime monthStartOf(int serial) =>
    DateTime.utc(yearOfMonth(serial), monthNumberOf(serial), 1);

int monthNumberOf(int serial) => _positiveModulo(serial, _monthsPerYear) + 1;

int yearOfMonth(int serial) => _floorDivide(serial, _monthsPerYear);

// MARK: - Grid
@immutable
class TrendsGrid {
  const TrendsGrid({
    required this.span,
    required this.alignmentAnchor,
    required this.currentSelection,
    required this.maximumEnd,
    required this.earliestEnd,
  });

  final int span;
  final int alignmentAnchor;
  final int currentSelection;
  final int maximumEnd;
  final int? earliestEnd;

  int alignedEnd(int requested) {
    final capped = math.min(requested, maximumEnd);
    final end =
        alignmentAnchor - span * _floorDivide(alignmentAnchor - capped, span);
    final earliest = earliestEnd;
    return earliest == null ? end : math.max(end, earliest);
  }

  int clampSelected(int selected, int end) =>
      selected.clamp(end - (span - 1), end);

  TrendsBasis basis(int requestedEnd, int requestedSelected) {
    final end = alignedEnd(requestedEnd);
    return TrendsBasis(
      end: end,
      selected: clampSelected(requestedSelected, end),
    );
  }

  bool canPage(int end, int direction) {
    final target = end + direction * span;
    final earliest = earliestEnd;
    return earliest != null && target >= earliest && target <= maximumEnd;
  }
}

// MARK: - Bounds
@immutable
class TrendsBounds {
  const TrendsBounds({
    required this.earliestMonthEnd,
    required this.earliestYearEnd,
  });

  factory TrendsBounds.fromFirstRecord(DateTime? first, int currentMonth) {
    final currentYear = yearOfMonth(currentMonth);
    final firstMonth = first == null ? null : monthSerial(first);
    final monthBack = firstMonth == null || firstMonth > currentMonth
        ? 0
        : _monthSpan * ((currentMonth - firstMonth) ~/ _monthSpan);
    final firstYear = first?.year;
    final yearBack = firstYear == null || firstYear > currentYear
        ? 0
        : _yearSpan * ((currentYear - firstYear) ~/ _yearSpan);
    return TrendsBounds(
      earliestMonthEnd: currentMonth - monthBack,
      earliestYearEnd: currentYear - yearBack,
    );
  }

  final int earliestMonthEnd;
  final int earliestYearEnd;
}

// MARK: - Context
@immutable
class TrendsContext {
  const TrendsContext({required this.currentMonth, this.bounds});

  final int currentMonth;
  final TrendsBounds? bounds;

  TrendsGrid grid(TrendsMode mode) => switch (mode) {
    TrendsMode.month => TrendsGrid(
      span: _monthSpan,
      alignmentAnchor:
          yearOfMonth(currentMonth) * _monthsPerYear + _monthsPerYear - 1,
      currentSelection: currentMonth,
      maximumEnd: _lastCompleteYearEnd,
      earliestEnd: _firstCompleteYearEnd,
    ),
    TrendsMode.year => TrendsGrid(
      span: _yearSpan,
      alignmentAnchor: yearOfMonth(currentMonth),
      currentSelection: yearOfMonth(currentMonth),
      maximumEnd: yearOfMonth(currentMonth),
      earliestEnd: bounds?.earliestYearEnd,
    ),
  };

  int get _firstCompleteYearEnd =>
      _minimumCompleteYear * _monthsPerYear + _monthsPerYear - 1;

  int get _lastCompleteYearEnd =>
      _maximumCompleteYear * _monthsPerYear + _monthsPerYear - 1;
}

// MARK: - Basis
@immutable
class TrendsBasis {
  const TrendsBasis({required this.end, required this.selected});

  final int end;
  final int selected;
}

// MARK: - Intent
@immutable
class TrendsIntent {
  const TrendsIntent({
    required this.kind,
    required this.mode,
    required this.spreadEnd,
    required this.selected,
    required this.rememberedMonth,
    required this.followsCurrent,
    this.rememberedBasis,
  });

  factory TrendsIntent.initial(DateTime today) {
    final current = monthSerial(today);
    return TrendsIntent(
      kind: TrendsKind.expense,
      mode: TrendsMode.month,
      spreadEnd: current,
      selected: current,
      rememberedMonth: monthNumberOf(current),
      followsCurrent: true,
    );
  }

  final TrendsKind kind;
  final TrendsMode mode;
  final int spreadEnd;
  final int selected;
  final int rememberedMonth;
  final bool followsCurrent;
  final TrendsBasis? rememberedBasis;

  TrendsBasis effective(TrendsContext context) {
    final grid = context.grid(mode);
    if (followsCurrent) {
      return grid.basis(grid.alignmentAnchor, grid.currentSelection);
    }
    return grid.basis(spreadEnd, selected);
  }

  TrendsIntent withKind(TrendsKind next, TrendsContext context) {
    if (next == kind) return this;
    return _adopting(context, kind: next, followsCurrent: followsCurrent);
  }

  TrendsIntent withMode(TrendsMode next, TrendsContext context) {
    if (next == mode) return this;
    final basis = effective(context);
    return switch (next) {
      TrendsMode.year => _toYear(basis, context),
      TrendsMode.month => _toMonth(basis, context),
    };
  }

  TrendsIntent withSlot(int index, TrendsContext context) {
    final span = context.grid(mode).span;
    if (index < 0 || index >= span) return this;
    final basis = effective(context);
    final selected = basis.end - (span - 1) + index;
    return _placed(
      basis.end,
      selected,
      rememberedBasis: mode == TrendsMode.year ? null : rememberedBasis,
    );
  }

  TrendsIntent pagedPrevious(TrendsContext context) =>
      _paged(_pagePrevious, context);

  TrendsIntent pagedNext(TrendsContext context) => _paged(_pageNext, context);

  TrendsIntent _paged(int direction, TrendsContext context) {
    final grid = context.grid(mode);
    final basis = effective(context);
    if (!grid.canPage(basis.end, direction)) return this;
    final shift = direction * grid.span;
    return _placed(
      basis.end + shift,
      basis.selected + shift,
      rememberedBasis: mode == TrendsMode.year ? null : rememberedBasis,
    );
  }

  TrendsIntent _toYear(TrendsBasis basis, TrendsContext context) {
    final grid = context.grid(TrendsMode.year);
    final year = yearOfMonth(basis.selected);
    final placed = grid.basis(year, year);
    return TrendsIntent(
      kind: kind,
      mode: TrendsMode.year,
      spreadEnd: placed.end,
      selected: placed.selected,
      rememberedMonth: monthNumberOf(basis.selected),
      followsCurrent: false,
      rememberedBasis: basis,
    );
  }

  TrendsIntent _toMonth(TrendsBasis basis, TrendsContext context) {
    final saved = rememberedBasis;
    final grid = context.grid(TrendsMode.month);
    if (saved != null) {
      final placed = grid.basis(saved.end, saved.selected);
      return TrendsIntent(
        kind: kind,
        mode: TrendsMode.month,
        spreadEnd: placed.end,
        selected: placed.selected,
        rememberedMonth: monthNumberOf(placed.selected),
        followsCurrent: false,
      );
    }
    final month = basis.selected * _monthsPerYear + rememberedMonth - 1;
    final placed = grid.basis(month, month);
    return TrendsIntent(
      kind: kind,
      mode: TrendsMode.month,
      spreadEnd: placed.end,
      selected: placed.selected,
      rememberedMonth: monthNumberOf(placed.selected),
      followsCurrent: false,
    );
  }

  TrendsIntent _placed(int end, int selected, {TrendsBasis? rememberedBasis}) =>
      TrendsIntent(
        kind: kind,
        mode: mode,
        spreadEnd: end,
        selected: selected,
        rememberedMonth: mode == TrendsMode.month
            ? monthNumberOf(selected)
            : rememberedMonth,
        followsCurrent: false,
        rememberedBasis: rememberedBasis,
      );

  TrendsIntent _adopting(
    TrendsContext context, {
    required TrendsKind kind,
    required bool followsCurrent,
  }) {
    final basis = effective(context);
    return TrendsIntent(
      kind: kind,
      mode: mode,
      spreadEnd: basis.end,
      selected: basis.selected,
      rememberedMonth: mode == TrendsMode.month
          ? monthNumberOf(basis.selected)
          : rememberedMonth,
      followsCurrent: followsCurrent,
      rememberedBasis: rememberedBasis,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrendsIntent &&
      other.kind == kind &&
      other.mode == mode &&
      other.spreadEnd == spreadEnd &&
      other.selected == selected &&
      other.rememberedMonth == rememberedMonth &&
      other.rememberedBasis?.end == rememberedBasis?.end &&
      other.rememberedBasis?.selected == rememberedBasis?.selected &&
      other.followsCurrent == followsCurrent;

  @override
  int get hashCode => Object.hash(
    kind,
    mode,
    spreadEnd,
    selected,
    rememberedMonth,
    rememberedBasis?.end,
    rememberedBasis?.selected,
    followsCurrent,
  );
}

// MARK: - IntentNotifier
class TrendsIntentNotifier extends Notifier<TrendsIntent> {
  @override
  TrendsIntent build() => TrendsIntent.initial(ref.read(todayProvider));

  void setKind(TrendsKind kind, TrendsContext context) =>
      _replace(state.withKind(kind, context));

  void setMode(TrendsMode mode, TrendsContext context) =>
      _replace(state.withMode(mode, context));

  void selectSlot(int index, TrendsContext context) =>
      _replace(state.withSlot(index, context));

  void previousPage(TrendsContext context) =>
      _replace(state.pagedPrevious(context));

  void nextPage(TrendsContext context) => _replace(state.pagedNext(context));

  void _replace(TrendsIntent next) {
    if (!identical(next, state)) state = next;
  }
}

final trendsIntentProvider =
    NotifierProvider.autoDispose<TrendsIntentNotifier, TrendsIntent>(
      TrendsIntentNotifier.new,
    );
