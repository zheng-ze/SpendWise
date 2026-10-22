import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/analysis/summaries/calendar.dart';
import 'package:spendwise/ledger/analysis/summaries/upcoming.dart';

const _checkingID = 'a0000000-0000-0000-0000-000000000001';
const _cardID = 'a0000000-0000-0000-0000-000000000002';
const _secondCardID = 'a0000000-0000-0000-0000-000000000004';
const _categoryID = 'a0000000-0000-0000-0000-000000000003';
const _planID = 'b0000000-0000-0000-0000-000000000001';
const _laterPlanID = 'b0000000-0000-0000-0000-000000000002';
const _entryID = 'c0000000-0000-0000-0000-000000000001';
const _laterEntryID = 'c0000000-0000-0000-0000-000000000002';
final _today = DateTime.utc(2026, 10, 1);
final _cutDay = DateTime.utc(2026, 10, 5);
final _window = DateRange(_today, DateTime.utc(2026, 10, 7));

LedgerState _ledger() {
  final state = LedgerState()
    ..addAccount(
      Account(id: _checkingID, name: 'Checking', type: AccountType.checking),
    )
    ..addAccount(
      Account(
        id: _cardID,
        name: 'Card',
        type: AccountType.card,
        statementDay: 5,
      ),
    )
    ..addAccount(
      Account(
        id: _secondCardID,
        name: 'Second card',
        type: AccountType.card,
        statementDay: 5,
      ),
    )
    ..addCategory(
      TransactionCategory(
        id: _categoryID,
        name: 'Food',
        kind: CategoryKind.expense,
        colorHex: '#000000',
        includeInAnalysis: true,
        parentID: null,
        symbol: 'tag',
      ),
    )
    ..addPlan(
      RecurringPlan(
        id: _planID,
        template: EntryTemplate(
          amount: Decimal.parse('-12'),
          name: 'Planned lunch',
          categoryID: _categoryID,
          sourceID: _checkingID,
        ),
        frequency: RecurrenceFrequency.weekly,
        anchor: _cutDay,
        lastResolvedDate: _today,
      ),
    )
    ..addPlan(
      RecurringPlan(
        id: _laterPlanID,
        template: EntryTemplate(
          amount: Decimal.parse('-14'),
          name: 'Planned dinner',
          sourceID: _checkingID,
        ),
        frequency: RecurrenceFrequency.weekly,
        anchor: _cutDay,
        lastResolvedDate: _today,
      ),
    )
    ..addEntry(
      Entry(
        id: _entryID,
        amount: Decimal.parse('-8'),
        name: 'Lunch',
        sourceID: _checkingID,
        categoryID: _categoryID,
        date: _cutDay,
      ),
    );
  state.addEntry(
    Entry(
      id: _laterEntryID,
      amount: Decimal.parse('-9'),
      name: 'Dinner',
      sourceID: _checkingID,
      date: _cutDay,
    ),
  );
  return state;
}

void main() {
  test(
    'upcoming items sort statements before plans before entries by date',
    () {
      final ledger = _ledger();
      final items = upcomingItems(
        ledger: ledger,
        today: _today,
        window: _window,
      );
      final repeated = upcomingItems(
        ledger: ledger,
        today: _today,
        window: _window,
      );

      expect(items, hasLength(6));
      expect(items[0], isA<UpcomingStatement>());
      expect((items[0] as UpcomingStatement).accountName, 'Card');
      expect((items[0] as UpcomingStatement).date, _cutDay);
      expect((items[1] as UpcomingStatement).accountName, 'Second card');
      expect(items[2], isA<UpcomingPlan>());
      expect((items[2] as UpcomingPlan).occurrence.planID, _planID);
      expect((items[3] as UpcomingPlan).occurrence.planID, _laterPlanID);
      expect((items[4] as UpcomingEntry).record.entry.id, _entryID);
      expect((items[5] as UpcomingEntry).record.entry.id, _laterEntryID);
      for (var index = 0; index < items.length; index++) {
        expect(items[index], repeated[index]);
        expect(items[index].hashCode, repeated[index].hashCode);
      }
    },
  );

  test(
    'plan occurrences and calendar days return identity and recorded state',
    () {
      final ledger = _ledger();
      final first = upcomingPlanOccurrences(
        ledger: ledger,
        today: _today,
        window: _window,
      );
      final second = upcomingPlanOccurrences(
        ledger: ledger,
        today: _today,
        window: _window,
      );
      final days = calendarDays(ledger: ledger, today: _today, window: _window);
      final matchingDay = CalendarDay(
        date: days.single.date,
        entries: days.single.entries,
        plans: days.single.plans,
      );

      expect(first, hasLength(2));
      expect(first.first, second.first);
      expect(first.first.hashCode, second.first.hashCode);
      expect(first.first.planID, _planID);
      expect(first.first.occurrenceID, OccurrenceID.make(_planID, _cutDay));
      expect(days, hasLength(1));
      expect(days.single, matchingDay);
      expect(days.single.hashCode, matchingDay.hashCode);
      expect(days.single.date, _cutDay);
      expect(days.single.entries.map((record) => record.entry.id), [
        _laterEntryID,
        _entryID,
      ]);
      expect(days.single.plans.map((occurrence) => occurrence.planID), [
        _planID,
        _laterPlanID,
      ]);
      expect(days.single.plans.first, first.first);
    },
  );
}
