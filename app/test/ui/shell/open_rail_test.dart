import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

const _openSize = Size(960, 720);
const _thresholdSize = Size(600, 480);

const _railLabels = [
  'Overview',
  'History',
  'Trends',
  'Money',
  'Settings',
  'Add',
];

Ledger _buildLedger() {
  final checking = Account(name: 'Checking', type: AccountType.checking);
  return Ledger(
    state: LedgerState(
      moneySources: {checking.id: MoneySource.account(checking)},
    ),
  );
}

Future<ProviderContainer> _pumpOpen(
  WidgetTester tester, {
  Size size = _openSize,
  ShellLayoutMode layoutMode = ShellLayoutMode.open,
  Ledger? ledger,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
      shellLayoutModeProvider.overrideWithValue(layoutMode),
      if (ledger != null) ledgerProvider.overrideWithValue(ledger),
      if (ledger != null)
        scanStripEnabledProvider.overrideWith((ref) async => false),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(() async {
    while (find.byType(AppSheet, skipOffstage: false).evaluate().isNotEmpty) {
      Navigator.of(
        tester.element(find.byType(AppSheet, skipOffstage: false).last),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();
    }
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppShell()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void _expectRailOrder(WidgetTester tester) {
  var previousDy = double.negativeInfinity;
  for (final label in _railLabels) {
    final dy = tester.getCenter(find.text(label)).dy;
    expect(dy, greaterThan(previousDy), reason: label);
    previousDy = dy;
  }
}

void main() {
  testWidgets('the rail orders destinations before a filled, never-selected '
      'Add', (tester) async {
    await _pumpOpen(tester);

    expect(find.byKey(openRailKey), findsOneWidget);
    _expectRailOrder(tester);

    expect(
      tester.getSemantics(find.text('Overview')),
      matchesSemantics(
        label: 'Overview',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Add')),
      matchesSemantics(
        label: 'Add',
        isButton: true,
        hasSelectedState: false,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );

    final badge = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.add),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (badge.decoration as BoxDecoration).color,
      SpendWiseColors.light.action,
    );
    expect(
      tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.add),
              matching: find.byType(Container),
            )
            .first,
      ),
      const Size(32, 32),
    );
    final badgeIcon = tester.widget<Icon>(find.byIcon(Icons.add));
    expect(badgeIcon.size, 22);
    expect(badgeIcon.color, SpendWiseColors.light.onAction);
  });

  testWidgets('the rail exposes a main-navigation landmark', (tester) async {
    await _pumpOpen(tester);

    expect(find.bySemanticsLabel(openRailNavigationLabel), findsOneWidget);
  });

  testWidgets('selecting a rail destination updates selection and semantics', (
    tester,
  ) async {
    final container = await _pumpOpen(tester);

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.trends,
    );
    expect(
      tester.getSemantics(find.text('Trends')),
      matchesSemantics(
        label: 'Trends',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Overview')),
      matchesSemantics(
        label: 'Overview',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Add')),
      matchesSemantics(
        label: 'Add',
        isButton: true,
        hasSelectedState: false,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
  });

  testWidgets('the rail docks bottom right with reference geometry', (
    tester,
  ) async {
    await _pumpOpen(tester);

    final railRect = tester.getRect(find.byKey(openRailKey));
    expect(railRect.width, moreOrLessEquals(openRailWidth, epsilon: 0.5));
    expect(
      railRect.right,
      moreOrLessEquals(_openSize.width - openRailRightInset, epsilon: 0.5),
    );
    expect(
      railRect.bottom,
      moreOrLessEquals(_openSize.height - openRailBottomInset, epsilon: 0.5),
    );
    final decoration =
        tester.widget<Container>(find.byKey(openRailKey)).decoration
            as BoxDecoration;
    expect(
      decoration.borderRadius,
      BorderRadius.circular(openRailCornerRadius),
    );
  });

  testWidgets('page content reserves the rail gutter and shows no header '
      'gear', (tester) async {
    await _pumpOpen(tester);

    final stackWidth = tester.getSize(find.byType(IndexedStack)).width;
    expect(
      stackWidth,
      moreOrLessEquals(_openSize.width - openRailGutter, epsilon: 0.5),
    );
    expect(find.byIcon(Icons.settings), findsNothing);
  });

  testWidgets('a right system inset extends the content gutter clear of '
      'the rail', (tester) async {
    tester.view.viewPadding = const FakeViewPadding(right: 20);
    tester.view.padding = const FakeViewPadding(right: 20);
    addTearDown(tester.view.reset);
    await _pumpOpen(tester);

    final stackWidth = tester.getSize(find.byType(IndexedStack)).width;
    expect(
      stackWidth,
      moreOrLessEquals(_openSize.width - openRailGutter - 20, epsilon: 0.5),
    );
    final railRect = tester.getRect(find.byKey(openRailKey));
    expect(
      railRect.right,
      moreOrLessEquals(_openSize.width - openRailRightInset - 20, epsilon: 0.5),
    );
    expect(stackWidth, lessThanOrEqualTo(railRect.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rail Add opens the shared sheet and keeps the selection', (
    tester,
  ) async {
    final container = await _pumpOpen(tester, ledger: _buildLedger());

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text('Add entry'), findsOneWidget);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.trends,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
  });

  testWidgets('the rail keeps every control reachable at the 600 x 480 '
      'threshold with safe insets', (tester) async {
    tester.view.viewPadding = const FakeViewPadding(
      left: 12,
      top: 24,
      right: 12,
      bottom: 20,
    );
    tester.view.padding = const FakeViewPadding(
      left: 12,
      top: 24,
      right: 12,
      bottom: 20,
    );
    addTearDown(tester.view.reset);
    await _pumpOpen(tester, size: _thresholdSize);

    expect(find.byKey(openRailKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final label in _railLabels) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail scrolls instead of overflowing on short windows and '
      'large text', (tester) async {
    tester.view.physicalSize = const Size(960, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
        shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(home: AppShell()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(openRailKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final label in _railLabels) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('phone and desktop chrome stay untouched', (tester) async {
    await _pumpOpen(tester, layoutMode: ShellLayoutMode.phone);
    expect(find.byKey(const ValueKey('phone-bar')), findsOneWidget);
    expect(find.byKey(openRailKey), findsNothing);

    await _pumpOpen(tester, layoutMode: ShellLayoutMode.desktop);
    expect(find.byKey(const ValueKey('sidebar')), findsOneWidget);
    expect(find.byKey(openRailKey), findsNothing);
  });

  testWidgets('rail hit targets meet the minimum size', (tester) async {
    await _pumpOpen(tester);

    for (final label in _railLabels) {
      final slot = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      final size = tester.getSize(
        find.descendant(of: slot, matching: find.byType(ConstrainedBox)).first,
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(tester.element(find.byKey(openRailKey)).colors.action, isNotNull);
  });
}
