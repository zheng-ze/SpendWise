import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_screen.dart';
import 'package:spendwise/ui/symbol_map.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';

import '../../../support/semantics_test_support.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  Account account(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
    Set<String> subPocketIDs = const {},
  }) => Account(
    id: id,
    name: name,
    type: AccountType.checking,
    lifecycle: lifecycle,
    subPocketIDs: subPocketIDs,
  );

  SubPocket pocket(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
  }) => SubPocket(id: id, name: name, lifecycle: lifecycle);

  TransactionCategory category(
    String id,
    String name, {
    LifecycleState lifecycle = LifecycleState.archived,
  }) => TransactionCategory(
    id: id,
    name: name,
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'tag',
    lifecycle: lifecycle,
  );

  Ledger buildLedger({
    Map<String, MoneySource> moneySources = const {},
    Map<String, TransactionCategory> categories = const {},
    Map<String, Entry> entries = const {},
    Map<String, Entry> binnedEntries = const {},
  }) {
    return Ledger(
      state: LedgerState(
        moneySources: moneySources,
        categories: categories,
        entries: entries,
        binnedEntries: binnedEntries,
      ),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, Ledger ledger) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
        child: const MaterialApp(home: RecycleBinScreen()),
      ),
    );
  }

  testWidgets('whole-screen empty message when nothing is archived', (
    tester,
  ) async {
    final ledger = buildLedger();
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('Recycle bin is empty'), findsOneWidget);
  });

  testWidgets('a section with no archived rows of that kind is not shown', (
    tester,
  ) async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Subpockets'), findsNothing);
    expect(find.text('Categories'), findsNothing);
    expect(find.text('Recycle bin is empty'), findsNothing);
  });

  testWidgets('reference counts are shown per row', (tester) async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final entry = Entry(amount: dec('5'), name: 'x', sourceID: acc.id);
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
      entries: {entry.id: entry},
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('1 reference'), findsOneWidget);
  });

  testWidgets('pocket qualified name shown when parent resolves', (
    tester,
  ) async {
    final parent = account(
      'a0000000-0000-0000-0000-000000000001',
      'Main',
      lifecycle: LifecycleState.active,
      subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
    );
    final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
    final ledger = buildLedger(
      moneySources: {
        parent.id: MoneySource.account(parent),
        pkt.id: MoneySource.pocket(pkt),
      },
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('Main/Rent'), findsOneWidget);
  });

  testWidgets('pocket unqualified name shown when parent id is not found', (
    tester,
  ) async {
    final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
    final ledger = buildLedger(moneySources: {pkt.id: MoneySource.pocket(pkt)});
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Main/Rent'), findsNothing);
  });

  testWidgets('rows are sorted by name within a section', (tester) async {
    final zebra = account('a0000000-0000-0000-0000-000000000001', 'Zebra');
    final alpha = account('a0000000-0000-0000-0000-000000000002', 'Alpha');
    final ledger = buildLedger(
      moneySources: {
        zebra.id: MoneySource.account(zebra),
        alpha.id: MoneySource.account(alpha),
      },
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    final alphaCenter = tester.getCenter(find.text('Alpha'));
    final zebraCenter = tester.getCenter(find.text('Zebra'));
    expect(alphaCenter.dy, lessThan(zebraCenter.dy));
  });

  testWidgets('leading swipe on an account restores it and it leaves the bin', (
    tester,
  ) async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Old Bank'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(ledger.state.moneySources[acc.id]!.lifecycle, LifecycleState.active);
    expect(find.text('Old Bank'), findsNothing);
    expect(find.text('Recycle bin is empty'), findsOneWidget);
  });

  testWidgets(
    'leading swipe on a pocket under a still-archived parent is a no-op',
    (tester) async {
      final parent = account(
        'a0000000-0000-0000-0000-000000000001',
        'Main',
        subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
      );
      final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
      final ledger = buildLedger(
        moneySources: {
          parent.id: MoneySource.account(parent),
          pkt.id: MoneySource.pocket(pkt),
        },
      );
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      await tester.drag(find.text('Main/Rent'), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(
        ledger.state.moneySources[pkt.id]!.lifecycle,
        LifecycleState.archived,
      );
      expect(find.text('Main/Rent'), findsOneWidget);
    },
  );

  testWidgets('trailing swipe shows the purge confirmation with exact copy', (
    tester,
  ) async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Old Bank'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete permanently?'), findsOneWidget);
    expect(
      find.text(
        'Old Bank leaves the bin for good. Existing transactions keep the '
        'name but it can no longer be restored.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('confirming purge on an account removes it from moneySources', (
    tester,
  ) async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Old Bank'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(ledger.state.moneySources.containsKey(acc.id), isFalse);
  });

  testWidgets('confirming purge on a pocket removes it from moneySources', (
    tester,
  ) async {
    final parent = account(
      'a0000000-0000-0000-0000-000000000001',
      'Main',
      lifecycle: LifecycleState.active,
      subPocketIDs: {'a0000000-0000-0000-0000-000000000002'},
    );
    final pkt = pocket('a0000000-0000-0000-0000-000000000002', 'Rent');
    final ledger = buildLedger(
      moneySources: {
        parent.id: MoneySource.account(parent),
        pkt.id: MoneySource.pocket(pkt),
      },
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Main/Rent'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(ledger.state.moneySources.containsKey(pkt.id), isFalse);
  });

  testWidgets('confirming purge on a category removes it from categories', (
    tester,
  ) async {
    final cat = category('a0000000-0000-0000-0000-000000000003', 'Old Cat');
    final ledger = buildLedger(categories: {cat.id: cat});
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Old Cat'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(ledger.state.categories.containsKey(cat.id), isFalse);
  });

  testWidgets('canceling the purge confirmation does not remove the row', (
    tester,
  ) async {
    final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
    final ledger = buildLedger(
      moneySources: {acc.id: MoneySource.account(acc)},
    );
    await pumpScreen(tester, ledger);
    await tester.pumpAndSettle();

    await tester.drag(find.text('Old Bank'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(ledger.state.moneySources.containsKey(acc.id), isTrue);
    expect(find.text('Old Bank'), findsOneWidget);
  });

  testWidgets(
    'the restore custom semantic action restores it, same as the leading '
    'swipe',
    (tester) async {
      final handle = tester.ensureSemantics();
      final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
      final ledger = buildLedger(
        moneySources: {acc.id: MoneySource.account(acc)},
      );
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      await performCustomSemanticsAction(
        tester,
        of: find.text('Old Bank'),
        label: 'Restore Old Bank',
      );
      await tester.pumpAndSettle();

      expect(
        ledger.state.moneySources[acc.id]!.lifecycle,
        LifecycleState.active,
      );
      expect(find.text('Old Bank'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets(
    'the purge custom semantic action shows the same purge confirmation as '
    'the trailing swipe and removes the row once confirmed',
    (tester) async {
      final handle = tester.ensureSemantics();
      final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
      final ledger = buildLedger(
        moneySources: {acc.id: MoneySource.account(acc)},
      );
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      await performCustomSemanticsAction(
        tester,
        of: find.text('Old Bank'),
        label: 'Purge Old Bank',
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete permanently?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(ledger.state.moneySources.containsKey(acc.id), isFalse);
      handle.dispose();
    },
  );

  group('Entries section', () {
    const sourceId = 'a0000000-0000-0000-0000-0000000000a1';
    final wallet = account(
      sourceId,
      'Wallet',
      lifecycle: LifecycleState.active,
    );

    Entry binned(String name, DateTime date, {String amount = '-5'}) => Entry(
      name: name,
      amount: dec(amount),
      date: date,
      sourceID: sourceId,
    ).settingLifecycle(LifecycleState.archived);

    Ledger ledgerWith(List<Entry> entries) => buildLedger(
      moneySources: {wallet.id: MoneySource.account(wallet)},
      binnedEntries: {for (final e in entries) e.id: e},
    );

    Future<Ledger> pumpWith(WidgetTester tester, List<Entry> entries) async {
      final ledger = ledgerWith(entries);
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();
      return ledger;
    }

    testWidgets('lists binned entries newest date first above other sections', (
      tester,
    ) async {
      final older = binned('Older lunch', DateTime.utc(2026, 9, 1));
      final newer = binned('Newer coffee', DateTime.utc(2026, 10, 3));
      final cat = category('a0000000-0000-0000-0000-000000000003', 'Old Cat');
      final ledger = buildLedger(
        moneySources: {wallet.id: MoneySource.account(wallet)},
        categories: {cat.id: cat},
        binnedEntries: {older.id: older, newer.id: newer},
      );
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('Entries'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Newer coffee')).dy,
        lessThan(tester.getCenter(find.text('Older lunch')).dy),
      );
      expect(
        tester.getCenter(find.text('Older lunch')).dy,
        lessThan(tester.getCenter(find.text('Categories')).dy),
      );
    });

    testWidgets('a row shows date, source name, kind-styled signed amount', (
      tester,
    ) async {
      await pumpWith(tester, [
        binned('Coffee', DateTime.utc(2026, 10, 3), amount: '-42.50'),
      ]);

      expect(find.text('3 Oct 2026 / Wallet'), findsOneWidget);
      expect(find.text('-42.50'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });

    testWidgets('the section is hidden when no entry is binned', (
      tester,
    ) async {
      final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
      final ledger = buildLedger(
        moneySources: {acc.id: MoneySource.account(acc)},
      );
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('Entries'), findsNothing);
    });

    testWidgets('the Restore text restores the entry without confirmation', (
      tester,
    ) async {
      final entry = binned('Coffee', DateTime.utc(2026, 10, 3));
      final ledger = await pumpWith(tester, [entry]);

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(ledger.state.entries.containsKey(entry.id), isTrue);
      expect(ledger.state.binnedEntries, isEmpty);
      expect(find.text('Delete permanently?'), findsNothing);
      expect(find.text('Entries'), findsNothing);
    });

    testWidgets('a leading swipe restores the entry', (tester) async {
      final entry = binned('Coffee', DateTime.utc(2026, 10, 3));
      final ledger = await pumpWith(tester, [entry]);

      await tester.drag(find.text('Coffee'), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(ledger.state.entries.containsKey(entry.id), isTrue);
      expect(find.text('Coffee'), findsNothing);
    });

    testWidgets('a trailing swipe then Delete purges the entry', (
      tester,
    ) async {
      final entry = binned('Coffee', DateTime.utc(2026, 10, 3));
      final ledger = await pumpWith(tester, [entry]);

      await tester.drag(find.text('Coffee'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete permanently?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(ledger.state.binnedEntries, isEmpty);
      expect(ledger.state.entries, isEmpty);
    });

    testWidgets('cancelling the purge confirmation keeps the entry', (
      tester,
    ) async {
      final entry = binned('Coffee', DateTime.utc(2026, 10, 3));
      final ledger = await pumpWith(tester, [entry]);

      await tester.drag(find.text('Coffee'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(ledger.state.binnedEntries.containsKey(entry.id), isTrue);
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('a binned entry counts toward another row reference count', (
      tester,
    ) async {
      final acc = account('a0000000-0000-0000-0000-000000000001', 'Old Bank');
      final entry = Entry(
        name: 'x',
        amount: dec('-5'),
        sourceID: acc.id,
      ).settingLifecycle(LifecycleState.archived);
      final ledger = buildLedger(
        moneySources: {acc.id: MoneySource.account(acc)},
        binnedEntries: {entry.id: entry},
      );
      await pumpScreen(tester, ledger);
      await tester.pumpAndSettle();

      expect(find.text('1 reference'), findsOneWidget);
    });

    Color amountColor(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style!.color!;

    testWidgets(
      'an unnamed categorized expense shows the category title and its '
      'category-coloured medallion icon',
      (tester) async {
        final cat = category(
          'a0000000-0000-0000-0000-000000000003',
          'Dining',
          lifecycle: LifecycleState.active,
        );
        final entry = Entry(
          name: '',
          amount: dec('-8'),
          date: DateTime.utc(2026, 10, 3),
          sourceID: sourceId,
          categoryID: cat.id,
        ).settingLifecycle(LifecycleState.archived);
        final ledger = buildLedger(
          moneySources: {wallet.id: MoneySource.account(wallet)},
          categories: {cat.id: cat},
          binnedEntries: {entry.id: entry},
        );
        await pumpScreen(tester, ledger);
        await tester.pumpAndSettle();

        expect(find.text('Dining'), findsOneWidget);
        final icon = tester.widget<Icon>(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == symbolIcon('tag'),
          ),
        );
        expect(icon.color, const Color(0xFFFF0000));
      },
    );

    testWidgets('an income entry shows a plus sign in the income colour', (
      tester,
    ) async {
      await pumpWith(tester, [
        binned('Salary', DateTime.utc(2026, 10, 3), amount: '100'),
      ]);

      expect(find.text('+100.00'), findsOneWidget);
      expect(amountColor(tester, '+100.00'), SpendWiseColors.light.income);
    });

    testWidgets('an expense entry shows a minus sign in the expense colour', (
      tester,
    ) async {
      await pumpWith(tester, [
        binned('Coffee', DateTime.utc(2026, 10, 3), amount: '-5'),
      ]);

      expect(amountColor(tester, '-5.00'), SpendWiseColors.light.expense);
    });

    testWidgets(
      'a transfer shows an unsigned amount in the neutral colour and a '
      'source > destination caption',
      (tester) async {
        final savings = account(
          'a0000000-0000-0000-0000-0000000000a2',
          'Savings',
          lifecycle: LifecycleState.active,
        );
        final transfer = Entry(
          name: 'Move',
          amount: dec('-20'),
          date: DateTime.utc(2026, 10, 3),
          sourceID: sourceId,
          destinationID: savings.id,
        ).settingLifecycle(LifecycleState.archived);
        final ledger = buildLedger(
          moneySources: {
            wallet.id: MoneySource.account(wallet),
            savings.id: MoneySource.account(savings),
          },
          binnedEntries: {transfer.id: transfer},
        );
        await pumpScreen(tester, ledger);
        await tester.pumpAndSettle();

        expect(find.text('3 Oct 2026 / Wallet > Savings'), findsOneWidget);
        expect(find.text('20.00'), findsOneWidget);
        expect(amountColor(tester, '20.00'), SpendWiseColors.light.text);
      },
    );
  });
}
