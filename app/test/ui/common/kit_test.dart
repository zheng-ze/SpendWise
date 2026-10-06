import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/app_buttons.dart';
import 'package:spendwise/ui/common/compact_labelled_fab.dart';
import 'package:spendwise/ui/common/empty_state.dart';
import 'package:spendwise/ui/common/error_section.dart';
import 'package:spendwise/ui/common/loading_skeleton.dart';
import 'package:spendwise/ui/common/medallion_row.dart';
import 'package:spendwise/ui/common/notice_card.dart';
import 'package:spendwise/ui/common/segmented_control.dart';
import 'package:spendwise/ui/common/summary_band.dart';
import 'package:spendwise/ui/common/tray.dart';
import 'package:spendwise/ui/format/money_format.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  final theme = buildSpendWiseTheme(brightness);
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );
}

SpendWiseColors _tokens(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold)))
        .extension<SpendWiseColors>()!;

void main() {
  group('PrimaryButton', () {
    testWidgets('renders filled and fires its action', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _host(
          PrimaryButton(label: 'Save entry', onPressed: () => fired = true),
        ),
      );

      expect(find.widgetWithText(FilledButton, 'Save entry'), findsOneWidget);
      await tester.tap(find.text('Save entry'));
      expect(fired, isTrue);
    });

    testWidgets('is disabled without an action', (tester) async {
      await tester.pumpWidget(
        _host(const PrimaryButton(label: 'Save entry', onPressed: null)),
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save entry'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a destructive action fills with the error token', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PrimaryButton(label: 'Delete', onPressed: () {}, destructive: true),
        ),
      );

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(button.style?.backgroundColor?.resolve({}), _tokens(tester).error);
    });
  });

  group('SecondaryButton', () {
    testWidgets('renders as text and fires its action', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _host(SecondaryButton(label: 'Cancel', onPressed: () => fired = true)),
      );

      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      expect(fired, isTrue);
    });

    testWidgets('renders as outline when asked', (tester) async {
      await tester.pumpWidget(
        _host(
          SecondaryButton(label: 'Today', onPressed: () {}, outlined: true),
        ),
      );

      expect(find.widgetWithText(OutlinedButton, 'Today'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Today'), findsNothing);
    });
  });

  group('Tray', () {
    testWidgets('draws its title and content on the surface token', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Tray(title: 'Budgets', child: Text('tray body'))),
      );

      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('tray body'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, _tokens(tester).surface);
    });
  });

  group('MedallionRow', () {
    testWidgets('shows its icon, title and trailing', (tester) async {
      await tester.pumpWidget(
        _host(
          const MedallionRow(
            icon: Icons.restaurant,
            title: 'Dining',
            subtitle: '3 entries',
            trailing: Text('S\$83.90'),
          ),
        ),
      );

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.text('Dining'), findsOneWidget);
      expect(find.text('3 entries'), findsOneWidget);
      expect(find.text('S\$83.90'), findsOneWidget);
    });
  });

  group('SummaryBand', () {
    testWidgets('colours the signed lead by its sign', (tester) async {
      await tester.pumpWidget(
        _host(
          SummaryBand(
            leadLabel: 'Net',
            leadAmount: Decimal.parse('3032.60'),
            cells: [
              SummaryBandCell(
                label: 'Spent',
                amount: Decimal.parse('167.40'),
                kind: AmountKind.expense,
                symbol: false,
              ),
            ],
          ),
        ),
      );

      Text leadAmount() => tester.widget<Text>(find.textContaining('3,032.60'));
      expect(leadAmount().style?.color, _tokens(tester).income);

      final cell = tester.widget<Text>(find.text('-167.40'));
      expect(cell.style?.color, _tokens(tester).expense);
    });
  });

  group('SegmentedControl', () {
    testWidgets('marks the chosen option and reports a new choice', (
      tester,
    ) async {
      var chosen = 'month';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SegmentedControl<String>(
                options: const [
                  SegmentedOption(value: 'month', label: 'Month by month'),
                  SegmentedOption(value: 'year', label: 'Year by year'),
                ],
                value: chosen,
                onChanged: (value) => chosen = value,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Year by year'));
      expect(chosen, 'year');
    });
  });

  group('CompactLabelledFab', () {
    testWidgets('fires its action and pairs action fill with foreground', (
      tester,
    ) async {
      var fired = false;
      await tester.pumpWidget(
        _host(
          CompactLabelledFab(
            label: 'Add budget',
            icon: Icons.add,
            onPressed: () => fired = true,
          ),
        ),
      );

      await tester.tap(find.text('Add budget'));
      expect(fired, isTrue);
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Add budget'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, _tokens(tester).action);
      expect(
        DefaultTextStyle.of(tester.element(find.text('Add budget')))
            .style
            .color,
        _tokens(tester).onAction,
      );
    });

    testWidgets('reserve space keeps the fab clear of list content', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FabReserveSpace()));

      expect(tester.getSize(find.byType(FabReserveSpace)).height, 58);
    });
  });

  group('NoticeCard', () {
    testWidgets('fills its first action and keeps the second quiet', (
      tester,
    ) async {
      var opened = false;
      var dismissed = false;
      await tester.pumpWidget(
        _host(
          NoticeCard(
            title: 'Spending is up',
            body: 'Groceries rose 20% this week.',
            primaryAction: NoticeCardAction(
              label: 'Open in Trends',
              onPressed: () => opened = true,
            ),
            secondaryAction: NoticeCardAction(
              label: 'Dismiss',
              onPressed: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Spending is up'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Open in Trends'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Dismiss'), findsOneWidget);

      await tester.tap(find.text('Open in Trends'));
      expect(opened, isTrue);
      await tester.tap(find.text('Dismiss'));
      expect(dismissed, isTrue);
    });
  });

  group('EmptyState', () {
    testWidgets('shows its title, body and filled action', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        _host(
          EmptyState(
            icon: Icons.receipt_long,
            title: 'No entries yet',
            body: 'Add your first entry to get started.',
            actionLabel: 'Add entry',
            onAction: () => fired = true,
          ),
        ),
      );

      expect(find.text('No entries yet'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add entry'), findsOneWidget);
      await tester.tap(find.text('Add entry'));
      expect(fired, isTrue);
    });
  });

  group('LoadingSkeleton', () {
    testWidgets('draws three trays by default', (tester) async {
      await tester.pumpWidget(_host(const LoadingTrays()));

      expect(find.byType(Tray), findsNWidgets(3));
    });
  });

  group('ErrorSection', () {
    testWidgets('keeps its message and offers a filled retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _host(
          ErrorSection(
            subject: 'account',
            error: const CategoryKindMismatch(),
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.textContaining('Could not save account'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('renders nothing without an error', (tester) async {
      await tester.pumpWidget(
        _host(const ErrorSection(subject: 'account', error: null)),
      );

      expect(find.textContaining('Could not save'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsNothing);
    });
  });
}
