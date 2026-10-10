import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/tray.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import 'overview_fixture.dart';

const _phoneSize = Size(320, 760);

Future<void> _pumpOverview(
  WidgetTester tester,
  LedgerState state, {
  required Brightness brightness,
}) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ledger = Ledger(state: state);
  final container = overviewContainer(ledger);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildSpendWiseTheme(brightness),
        home: const OverviewFlow(),
      ),
    ),
  );
  await tester.runAsync(() => settleAnalysis(container, ledger));
  await tester.pumpAndSettle();
}

Finder _inTray(String title, String text) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Tray)),
  matching: find.text(text),
);

Color? _textColor(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style?.color;

void main() {
  for (final brightness in Brightness.values) {
    final colors = brightness == Brightness.dark
        ? SpendWiseColors.dark
        : SpendWiseColors.light;

    group('ov-default in ${brightness.name}', () {
      testWidgets('shows the header, Today, Recent entries and Coming up', (
        tester,
      ) async {
        await _pumpOverview(tester, defaultState(), brightness: brightness);

        expect(find.text('Saturday, 3 October'), findsOneWidget);
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Today / 3 October'), findsOneWidget);
        expect(find.text('S\$45.70'), findsOneWidget);
        expect(find.text('Daily guide: about S\$39'), findsOneWidget);
        expect(find.text('From your S\$1,200 monthly cap.'), findsOneWidget);
        expect(find.text('Recent entries'), findsOneWidget);
        expect(find.text('View History'), findsOneWidget);
        expect(find.text('Coming up'), findsOneWidget);
        expect(find.text('Next 6 weeks'), findsOneWidget);
        expect(find.text('Edit Overview'), findsNothing);
        final order = [
          'Today / 3 October',
          'Recent entries',
          'Coming up',
        ].map((label) => tester.getTopLeft(find.text(label)).dy).toList();
        expect(order, [...order]..sort());
      });

      testWidgets('renders four recent rows with signed, styled amounts', (
        tester,
      ) async {
        await _pumpOverview(tester, defaultState(), brightness: brightness);

        for (final title in [
          'Snack',
          'Shop run',
          'To savings',
          'Monthly pay',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(find.text('Yesterday bite'), findsNothing);
        expect(find.text('Today / Salary / Checking'), findsOneWidget);
        expect(
          find.text('Today / Transfer / Checking > Savings'),
          findsOneWidget,
        );
        final income = _inTray('Recent entries', '+3,200.00');
        final moved = _inTray('Recent entries', '500.00');
        final spent = _inTray('Recent entries', '-42.50');
        expect(income, findsOneWidget);
        expect(moved, findsOneWidget);
        expect(spent, findsOneWidget);
        expect(_inTray('Recent entries', '-3.20'), findsOneWidget);
        expect(_textColor(tester, income), colors.income);
        expect(_textColor(tester, spent), colors.expense);
        expect(_textColor(tester, moved), colors.text);
      });

      testWidgets('renders the upcoming rows in date order', (tester) async {
        await _pumpOverview(tester, defaultState(), brightness: brightness);

        final titles = [
          'Amex Card statement closes',
          'Streaming',
          'Wages',
          'Rent',
        ];
        final tops = [
          for (final title in titles) tester.getTopLeft(find.text(title)).dy,
        ];
        expect(tops, [...tops]..sort());
        expect(find.text('This cycle so far: S\$45.70'), findsOneWidget);
        expect(find.text('Plan / Amex Card'), findsOneWidget);
        expect(find.text('Plan / Checking'), findsOneWidget);
        expect(find.text('Dated ahead / Checking'), findsOneWidget);
        expect(_inTray('Coming up', '-19.98'), findsOneWidget);
        expect(_inTray('Coming up', '+3,200.00'), findsOneWidget);
        expect(_inTray('Coming up', '-1,200.00'), findsOneWidget);
        expect(find.text('Oct'), findsNWidgets(3));
        expect(find.text('Nov'), findsOneWidget);
      });

      testWidgets('asks for a monthly cap when no unscoped budget exists', (
        tester,
      ) async {
        final state = emptyState();
        state.addEntry(
          entry(
            1,
            '-5.00',
            fixtureToday,
            name: 'Lunch',
            categoryID: groceriesID,
          ),
        );
        await _pumpOverview(tester, state, brightness: brightness);

        expect(
          find.text('Set a monthly cap to see a daily guide.'),
          findsOneWidget,
        );
        expect(find.text('Set a monthly cap'), findsOneWidget);
        expect(find.textContaining('Daily guide'), findsNothing);
      });

      testWidgets('is never empty on a fresh install', (tester) async {
        await _pumpOverview(tester, LedgerState(), brightness: brightness);

        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Nothing recorded today'), findsOneWidget);
        expect(find.text('Recent entries'), findsOneWidget);
        expect(find.text('Your entries will appear here.'), findsOneWidget);
        expect(find.text('Coming up'), findsOneWidget);
        expect(
          find.text('No known dates in the next six weeks.'),
          findsOneWidget,
        );
        expect(find.text('View History'), findsNothing);
      });
    });
  }
}
