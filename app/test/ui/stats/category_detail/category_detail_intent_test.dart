import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/category_detail/category_detail_args.dart';
import 'package:spendwise/ui/stats/category_detail/category_detail_intent.dart';
import 'package:spendwise/ui/stats/category_detail/category_scope.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

final _currentMonth = monthSerial(DateTime.utc(2026, 10, 23));

void main() {
  test('initial trend mode and bounds use the immutable incoming period', () {
    final monthArgs = _args(DateTime.utc(2025, 3, 15));
    final monthIntent = CategoryDetailIntent.initial(monthArgs);
    final yearArgs = _args(DateTime.utc(2025, 3, 15), year: true);
    final yearIntent = CategoryDetailIntent.initial(yearArgs);

    expect(monthIntent.trend.mode, TrendsMode.month);
    expect(monthIntent.trend.spreadEnd, monthSerial(DateTime.utc(2025, 3)));
    expect(monthIntent.trend.selected, monthSerial(DateTime.utc(2025, 3)));
    expect(monthIntent.trend.followsCurrent, isFalse);
    expect(_context(DateTime.utc(2010, 1)).grid(TrendsMode.month).span, 12);
    expect(yearIntent.trend.mode, TrendsMode.year);
    expect(yearIntent.trend.spreadEnd, 2025);
    expect(yearIntent.trend.selected, 2025);
    expect(_context(DateTime.utc(2010, 1)).grid(TrendsMode.year).span, 3);
    expect(monthArgs.initialDate, DateTime.utc(2025, 3, 15));
  });

  test('scope changes preserve the requested calendar-year basis', () {
    final args = _args(DateTime.utc(2017, 10));
    final allContext = _context(DateTime.utc(2010, 10));
    final laterChildContext = _context(DateTime.utc(2024, 3));
    final initial = CategoryDetailIntent.initial(args);
    final selected = initial.selectSlot(5, allContext);
    final requestedEnd = selected.trend.spreadEnd;
    final requestedSelection = selected.trend.selected;
    final narrowed = selected.withScope(const SubScope('child'));
    final narrowedBasis = narrowed.trend.effective(laterChildContext);

    expect(narrowed.trend.spreadEnd, requestedEnd);
    expect(narrowed.trend.selected, requestedSelection);
    expect(narrowedBasis.end, requestedEnd);
    expect(narrowedBasis.selected, requestedSelection);

    final widened = narrowed.withScope(const AllScope());
    expect(widened.trend.effective(allContext).end, requestedEnd);
    expect(widened.trend.effective(allContext).selected, requestedSelection);

    final paged = narrowed.nextPage(laterChildContext);
    expect(paged.trend.spreadEnd, narrowedBasis.end + 12);
    expect(paged.trend.selected, narrowedBasis.selected + 12);
    expect(
      paged.withScope(const AllScope()).trend.effective(allContext).end,
      narrowedBasis.end + 12,
    );
  });

  test(
    'mode and paging transitions preserve the effective selected period',
    () {
      final args = _args(DateTime.utc(2026, 10));
      final bounded = _context(DateTime.utc(2010, 1));
      final selected = CategoryDetailIntent.initial(args)
          .selectSlot(4, bounded);
      final year = selected.withMode(TrendsMode.year, bounded);

      expect(year.trend.mode, TrendsMode.year);
      expect(year.trend.rememberedMonth, 5);
      expect(year.trend.effective(bounded).selected, 2026);

      final selectedAgain = year.selectSlot(2, bounded);
      final unchangedMode = selectedAgain.withMode(TrendsMode.year, bounded);
      expect(identical(unchangedMode, selectedAgain), isTrue);
      expect(
        identical(selectedAgain.selectSlot(-1, bounded), selectedAgain),
        isTrue,
      );

      final paged = selectedAgain.previousPage(bounded);
      expect(paged.trend.spreadEnd, year.trend.spreadEnd - 3);
      expect(
        paged.trend.effective(bounded).selected,
        year.trend.effective(bounded).selected - 3,
      );
    },
  );

  test('empty-scope month pages remain available', () {
    final context = _context(null);
    final initial = CategoryDetailIntent.initial(_args(DateTime.utc(2026, 10)));
    final selected = initial.selectSlot(0, context);
    final previous = selected.previousPage(context);

    expect(context.bounds!.earliestMonthEnd, _currentMonth);
    expect(identical(previous, selected), isFalse);
    expect(
      previous.trend.effective(context).selected,
      selected.trend.effective(context).selected - 12,
    );
  });
}

CategoryDetailArgs _args(DateTime date, {bool year = false}) {
  return CategoryDetailArgs(
    mainID: 'a0000000-0000-0000-0000-000000000001',
    kind: CategoryKind.expense,
    isYearRange: year,
    initialDate: date,
  );
}

TrendsContext _context(DateTime? firstRecord) {
  final bounds = TrendsBounds.fromFirstRecord(firstRecord, _currentMonth);
  return TrendsContext(currentMonth: _currentMonth, bounds: bounds);
}
