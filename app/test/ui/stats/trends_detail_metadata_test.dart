import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/trends/trends_detail_metadata.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';

void main() {
  final today = DateTime.utc(2026, 10, 15);

  test('default selection identifies and titles the current month', () {
    final metadata = deriveTrendsDetailMetadata(
      intent: TrendsIntent.initial(today),
      today: today,
    );

    expect(metadata.id, 'month:2026-10');
    expect(metadata.title, 'October 2026');
  });

  test('selected historical month uses its clamped effective period', () {
    final context = TrendsContext(currentMonth: monthSerial(today));
    final intent = TrendsIntent.initial(today).withSlot(8, context);
    final metadata = deriveTrendsDetailMetadata(intent: intent, today: today);

    expect(metadata.id, 'month:2026-07');
    expect(metadata.title, 'July 2026');
  });

  test('year mode identifies and titles its selected calendar year', () {
    final context = TrendsContext(currentMonth: monthSerial(today));
    final intent = TrendsIntent.initial(today)
        .withMode(TrendsMode.year, context);
    final metadata = deriveTrendsDetailMetadata(intent: intent, today: today);

    expect(metadata.id, 'year:2026');
    expect(metadata.title, '2026');
  });

  test('user-selected year receives its own identity and title', () {
    final context = TrendsContext(currentMonth: monthSerial(today));
    final intent = TrendsIntent.initial(today)
        .withMode(TrendsMode.year, context)
        .withSlot(1, context);
    final metadata = deriveTrendsDetailMetadata(intent: intent, today: today);

    expect(metadata.id, 'year:2025');
    expect(metadata.title, '2025');
  });

  test(
    'bounds clamp old selection while absent bounds retain unbounded context',
    () {
      const intent = TrendsIntent(
        kind: TrendsKind.expense,
        mode: TrendsMode.month,
        spreadEnd: 2020 * 12,
        selected: 2020 * 12,
        rememberedMonth: 1,
        followsCurrent: false,
      );
      final bounds = TrendsBounds.fromFirstRecord(
        DateTime.utc(2024, 1),
        monthSerial(today),
      );

      final unbounded = deriveTrendsDetailMetadata(
        intent: intent,
        today: today,
      );
      final bounded = deriveTrendsDetailMetadata(
        intent: intent,
        today: today,
        bounds: bounds,
      );

      expect(unbounded.id, 'month:2020-01');
      expect(bounded.id, 'month:2023-11');
      expect(bounded.title, 'November 2023');
    },
  );

  test('kind and repeated identical inputs do not change metadata', () {
    final context = TrendsContext(currentMonth: monthSerial(today));
    final intent = TrendsIntent.initial(today).withSlot(8, context);
    final incomeIntent = intent.withKind(TrendsKind.income, context);
    final first = deriveTrendsDetailMetadata(intent: intent, today: today);
    final changedKind = deriveTrendsDetailMetadata(
      intent: incomeIntent,
      today: today,
    );
    final repeated = deriveTrendsDetailMetadata(intent: intent, today: today);

    expect(changedKind, first);
    expect(repeated, first);
  });
}
