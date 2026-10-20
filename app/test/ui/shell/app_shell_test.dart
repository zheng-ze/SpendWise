import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/add_sheet_dismiss.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../overview/overview_fixture.dart' show emptyState, settleAnalysis;
import '../../support/ui_test_timeout.dart';

const _compact = Size(400, 800);
const _wide = Size(1200, 900);
const _openSized = Size(960, 720);
const _openInsets = FakeViewPadding(left: 20, right: 30);
const _rightOnlyInset = FakeViewPadding(right: 30);
const _paneHostPageKey = ValueKey('pane-host-page');

const _phoneBarKey = ValueKey('phone-bar');
const _openRailKey = ValueKey('open-rail');
const _sidebarKey = ValueKey('sidebar');

const _destinationCount = 4;

const _barLabels = ['Overview', 'History', 'Add', 'Money', 'Settings'];

class _ProbeFlow extends FlowBase<String> {
  const _ProbeFlow({super.key, required this.label});

  final String label;

  @override
  ConsumerState<_ProbeFlow> createState() => _ProbeFlowState();
}

class _ProbeFlowState extends FlowBaseState<String, _ProbeFlow> {
  @override
  void Function() subscribeToStep(void Function(String? step) handle) => () {};

  @override
  void handleStep(BuildContext context, String step) {}

  @override
  Widget buildRoot(BuildContext context) => Text(widget.label);
}

Ledger _buildLedger() {
  final checking = Account(name: 'Checking', type: AccountType.checking);
  return Ledger(
    state: LedgerState(
      moneySources: {checking.id: MoneySource.account(checking)},
    ),
  );
}

Map<ShellDestination, WidgetBuilder> _probeBodies() => {
  ShellDestination.overview: (context) =>
      const _ProbeFlow(label: 'overview probe'),
  ShellDestination.history: (context) =>
      const _ProbeFlow(label: 'history probe'),
  ShellDestination.money: (context) => const _ProbeFlow(label: 'money probe'),
  ShellDestination.settings: (context) =>
      const _ProbeFlow(label: 'settings probe'),
};

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  required Size size,
  ShellLayoutMode layoutMode = ShellLayoutMode.phone,
  Map<ShellDestination, WidgetBuilder>? bodies,
  Ledger? ledger,
  String? Function()? moneySourceId,
  FakeViewPadding insets = FakeViewPadding.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = insets;
  tester.view.padding = insets;
  addTearDown(tester.view.reset);
  if (ledger != null) {
    addTearDown(() async {
      while (find.byType(AppSheet, skipOffstage: false).evaluate().isNotEmpty) {
        Navigator.of(
          tester.element(find.byType(AppSheet, skipOffstage: false).last),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
      }
    });
  }

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

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: AppShell(
          bodies: bodies ?? _probeBodies(),
          moneySourceId: moneySourceId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpBoundShell(
  WidgetTester tester, {
  required Size size,
  Map<ShellDestination, WidgetBuilder>? bodies,
  Ledger? ledger,
  bool settleAnalysisCache = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final ownedLedger = ledger ?? _buildLedger();
  final container = ProviderContainer(
    overrides: [
      hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
      shellPlatformProvider.overrideWithValue((
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      )),
      ledgerProvider.overrideWithValue(ownedLedger),
      scanStripEnabledProvider.overrideWith((ref) async => false),
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: buildShellAppContent,
        home: AppShell(bodies: bodies ?? _probeBodies()),
      ),
    ),
  );
  if (settleAnalysisCache) {
    await tester.runAsync(() => settleAnalysis(container, ownedLedger));
  }
  await tester.pumpAndSettle();
  return container;
}

Ledger _ledgerWithEntry(StringBuffer entryIdOut) {
  final ledger = _buildLedger();
  final entry = Entry(
    amount: Decimal.parse('-5'),
    name: 'Coffee run',
    sourceID: ledger.state.moneySources.keys.single,
    date: DateTime.utc(2026, 10, 3),
  );
  ledger.addEntry(entry);
  entryIdOut.write(entry.id);
  return ledger;
}

void _expectBarOrder(WidgetTester tester) {
  var previousDx = double.negativeInfinity;
  for (final label in _barLabels) {
    final dx = tester.getCenter(find.text(label)).dx;
    expect(dx, greaterThan(previousDx));
    previousDx = dx;
  }
}

void main() {
  testWidgets('open viewport applies horizontal safe insets exactly once', (
    tester,
  ) async {
    Widget insetProbe(BuildContext context) => SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = MediaQuery.paddingOf(context);
          return Text(
            'padding:${padding.left}:${padding.right};'
            'width:${constraints.maxWidth}',
          );
        },
      ),
    );

    await _pumpShell(
      tester,
      size: _openSized,
      layoutMode: ShellLayoutMode.open,
      insets: _openInsets,
      bodies: {ShellDestination.overview: insetProbe},
    );

    expect(find.text('padding:0.0:0.0;width:838.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('open pane host splits the safe body around the rail gutter', (
    tester,
  ) async {
    final detail = ShellDetail(
      id: 'selected',
      title: 'Selected',
      bodyBuilder: (_) => const SizedBox.shrink(),
      onClose: () {},
    );
    Widget paneHost(BuildContext context) => ShellPaneHost(
      pageBuilder: (_, _) => const SizedBox.expand(key: _paneHostPageKey),
      detail: detail,
    );

    await _pumpShell(
      tester,
      size: _openSized,
      layoutMode: ShellLayoutMode.open,
      insets: _rightOnlyInset,
      bodies: {ShellDestination.overview: paneHost},
    );

    const safeWidth = 960.0 - 30;
    expect(tester.getSize(find.byKey(_paneHostPageKey)).width, safeWidth / 2);
    expect(
      tester.getSize(find.byKey(shellDetailPaneKey)).width,
      safeWidth / 2 - openRailGutter,
    );
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('the shell opens on the overview destination', (tester) async {
    final container = await _pumpShell(tester, size: _compact);

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
    expect(find.text('overview probe'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('phone bar shows Overview, History, Add, Money, Settings in '
      'order', (tester) async {
    await _pumpShell(tester, size: _compact);

    expect(find.byKey(_phoneBarKey), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    _expectBarOrder(tester);
  }, timeout: uiTestTimeout);

  testWidgets('every layout mounts four keyed stack slots with History built '
      'once', (tester) async {
    for (final layoutMode in ShellLayoutMode.values) {
      await _pumpShell(
        tester,
        size: layoutMode == ShellLayoutMode.phone ? _compact : _wide,
        layoutMode: layoutMode,
      );

      for (final destination in shellDestinations) {
        expect(
          find.byKey(ValueKey(destination), skipOffstage: false),
          findsOneWidget,
        );
      }
      expect(shellDestinations, hasLength(_destinationCount));
      expect(find.text('history probe', skipOffstage: false), findsOneWidget);
    }
  }, timeout: uiTestTimeout);

  testWidgets('Add sits at the exact bar center with equal spacing', (
    tester,
  ) async {
    await _pumpShell(tester, size: _compact);

    final barRect = tester.getRect(find.byKey(_phoneBarKey));
    final centers = [
      for (final label in _barLabels) tester.getCenter(find.text(label)).dx,
    ];
    final gaps = [
      for (var i = 1; i < centers.length; i++) centers[i] - centers[i - 1],
    ];
    for (final gap in gaps) {
      expect(gap, moreOrLessEquals(gaps.first, epsilon: 1));
    }
    expect(centers[2], moreOrLessEquals(barRect.center.dx, epsilon: 1));
  }, timeout: uiTestTimeout);

  testWidgets('Add has button semantics and is never selected', (tester) async {
    await _pumpShell(tester, size: _compact);

    expect(
      tester.getSemantics(find.text('Add')),
      matchesSemantics(
        label: 'Add',
        isButton: true,
        hasSelectedState: false,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
  }, timeout: uiTestTimeout);

  testWidgets('phone destinations report selected semantics on selection', (
    tester,
  ) async {
    await _pumpShell(tester, size: _compact);

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

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('History')),
      matchesSemantics(
        label: 'History',
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
  }, timeout: uiTestTimeout);

  testWidgets('Add from every phone destination opens the shared sheet and '
      'keeps the selection', (tester) async {
    final container = await _pumpShell(
      tester,
      size: _compact,
      ledger: _buildLedger(),
    );

    for (final destination in ['Overview', 'History', 'Money', 'Settings']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSheet), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);

      await dismissAddSheet(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsNothing);
    }

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
  }, timeout: uiTestTimeout);

  testWidgets('phone keeps one History host while visiting every destination', (
    tester,
  ) async {
    await _pumpShell(tester, size: _compact);

    for (final destination in ['History', 'Money', 'Settings', 'Overview']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
    }

    expect(find.text('history probe', skipOffstage: false), findsOneWidget);
    expect(find.text('overview probe'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('the shell shows no header gear or Add FAB', (tester) async {
    await _pumpShell(tester, size: _compact);

    for (final destination in ['Overview', 'History', 'Money', 'Settings']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.settings), findsNothing);
    }
  }, timeout: uiTestTimeout);

  testWidgets('system insets stay outside the bar pill', (tester) async {
    await _pumpShell(tester, size: _compact);

    final plain = tester.getSize(find.byKey(_phoneBarKey)).height;

    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    await tester.pumpAndSettle();

    expect(find.byKey(_phoneBarKey), findsOneWidget);
    expect(tester.getSize(find.byKey(_phoneBarKey)).height, plain);
  }, timeout: uiTestTimeout);

  testWidgets('desktop sidebar shows the wordmark, destinations, Add entry '
      'and bottom Settings', (tester) async {
    await _pumpShell(tester, size: _wide, layoutMode: ShellLayoutMode.desktop);

    expect(find.byKey(_sidebarKey), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('SpendWise', findRichText: true), findsOneWidget);
    for (final label in ['Overview', 'History', 'Money', 'Settings']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Add entry'), findsOneWidget);

    final settingsDy = tester.getCenter(find.text('Settings')).dy;
    for (final label in ['Overview', 'History', 'Money']) {
      expect(tester.getCenter(find.text(label)).dy, lessThan(settingsDy));
    }
  }, timeout: uiTestTimeout);

  testWidgets('desktop History hosts its body with no phone back control', (
    tester,
  ) async {
    await _pumpShell(tester, size: _wide, layoutMode: ShellLayoutMode.desktop);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('history probe'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('desktop Add entry opens the shared sheet and keeps the '
      'selection', (tester) async {
    final container = await _pumpShell(
      tester,
      size: _wide,
      layoutMode: ShellLayoutMode.desktop,
      ledger: _buildLedger(),
    );

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsOneWidget);
    expect(find.text('Add entry'), findsWidgets);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.history,
    );

    await dismissAddSheet(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
  }, timeout: uiTestTimeout);

  for (final layoutMode in ShellLayoutMode.values) {
    testWidgets('$layoutMode Add captures the scoped Money source', (
      tester,
    ) async {
      final ledger = _buildLedger();
      final sourceId = ledger.state.moneySources.keys.single;
      await _pumpShell(
        tester,
        size: layoutMode == ShellLayoutMode.phone ? _compact : _wide,
        layoutMode: layoutMode,
        ledger: ledger,
        moneySourceId: () => sourceId,
        bodies: {
          ..._probeBodies(),
          ShellDestination.money: (_) => const TransactionsFlow(),
        },
      );

      await tester.tap(find.text('Money'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(layoutMode == ShellLayoutMode.desktop ? 'Add entry' : 'Add'),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.text('Add entry').last),
      );
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        sourceId,
      );

      await dismissAddSheet(tester);
      await tester.pumpAndSettle();
    }, timeout: uiTestTimeout);
  }

  for (final width in [320.0, 720.0, 1440.0]) {
    testWidgets(
      'phone mode keeps the bar at ${width.toInt()}px logical width',
      (tester) async {
        await _pumpShell(tester, size: Size(width, 800));

        expect(find.byKey(_phoneBarKey), findsOneWidget);
        expect(find.byKey(_sidebarKey), findsNothing);
      },
      timeout: uiTestTimeout,
    );

    testWidgets(
      'desktop mode keeps the sidebar at ${width.toInt()}px logical width',
      (tester) async {
        await _pumpShell(
          tester,
          size: Size(width, 800),
          layoutMode: ShellLayoutMode.desktop,
        );

        expect(find.byKey(_sidebarKey), findsOneWidget);
        expect(find.byKey(_phoneBarKey), findsNothing);
      },
      timeout: uiTestTimeout,
    );
  }

  testWidgets('resizing phone to open and back switches chrome and keeps '
      'the selection', (tester) async {
    final container = await _pumpBoundShell(tester, size: _compact);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await _resize(tester, _openSized);
    expect(find.byKey(_openRailKey), findsOneWidget);
    expect(find.byKey(_phoneBarKey), findsNothing);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.history,
    );

    await _resize(tester, _compact);
    expect(find.byKey(_phoneBarKey), findsOneWidget);
    expect(find.byKey(_openRailKey), findsNothing);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
    expect(find.text('history probe'), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('resizing a desktop shell switches no layout', (tester) async {
    await _pumpShell(tester, size: _wide, layoutMode: ShellLayoutMode.desktop);

    for (final width in [1200.0, 1000.0, 960.0, 720.0, 680.0, 320.0]) {
      await _resize(tester, Size(width, 900));
      expect(find.byKey(_sidebarKey), findsOneWidget);
      expect(find.byKey(_phoneBarKey), findsNothing);
    }
  }, timeout: uiTestTimeout);

  testWidgets('a drilled-in destination keeps its stack across a switch', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: _compact,
      bodies: {
        ..._probeBodies(),
        ShellDestination.overview: (context) => Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('entry detail')),
                  ),
                ),
                child: const Text('open detail'),
              ),
            ),
          ),
        ),
      },
    );

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();
    expect(find.text('entry detail'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('entry detail'), findsNothing);

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('entry detail'), findsOneWidget);
    expect(find.text('open detail'), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('a drilled-in destination keeps its stack across a real '
      'mobile switch', (tester) async {
    await _pumpBoundShell(
      tester,
      size: _compact,
      bodies: {
        ..._probeBodies(),
        ShellDestination.overview: (context) => Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('entry detail')),
                  ),
                ),
                child: const Text('open detail'),
              ),
            ),
          ),
        ),
      },
    );

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    await _resize(tester, _openSized);

    expect(find.text('entry detail'), findsOneWidget);
    expect(find.byKey(_openRailKey), findsOneWidget);

    await _resize(tester, _compact);

    expect(find.text('entry detail'), findsOneWidget);
    expect(find.byKey(_phoneBarKey), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('selecting Settings shows its body and retains other stacks', (
    tester,
  ) async {
    final container = await _pumpShell(
      tester,
      size: _compact,
      bodies: {
        ..._probeBodies(),
        ShellDestination.overview: (context) => Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('entry detail')),
                  ),
                ),
                child: const Text('open detail'),
              ),
            ),
          ),
        ),
      },
    );

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
    expect(find.text('settings probe'), findsOneWidget);

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('entry detail'), findsOneWidget);
  }, timeout: uiTestTimeout);

  group('destination Back activity', () {
    Future<void> pumpProbes(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IndexedStack(
            index: 0,
            children: [
              DestinationActivity(
                active: true,
                child: _ProbeFlow(label: 'active'),
              ),
              DestinationActivity(
                active: false,
                child: _ProbeFlow(label: 'hidden'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pushProbeChild(WidgetTester tester, String label) async {
      final root = tester.element(find.text(label, skipOffstage: false));
      Navigator.of(root)
          .push(MaterialPageRoute<void>(builder: (_) => Text('$label child')));
      await tester.pumpAndSettle();
    }

    testWidgets('an inactive destination ignores system Back', (tester) async {
      await pumpProbes(tester);
      await pushProbeChild(tester, 'active');
      await pushProbeChild(tester, 'hidden');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('active child'), findsNothing);
      expect(find.text('active'), findsOneWidget);
      expect(find.text('hidden child', skipOffstage: false), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('Back at an active root preserves every stack', (tester) async {
      await pumpProbes(tester);
      await pushProbeChild(tester, 'hidden');

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('active'), findsOneWidget);
      expect(find.text('hidden', skipOffstage: false), findsOneWidget);
      expect(find.text('hidden child', skipOffstage: false), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a standalone Flow keeps active Back behavior', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _ProbeFlow(label: 'solo')),
      );
      await tester.pumpAndSettle();
      await pushProbeChild(tester, 'solo');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('solo child'), findsNothing);
      expect(find.text('solo'), findsOneWidget);
    }, timeout: uiTestTimeout);
  });

  testWidgets('a shell rebuild keeps a non-current selected month', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
        shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.phone),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = _compact;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> mountShell(Key key) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppShell(
            key: key,
            bodies: {
              ShellDestination.overview: (context) => Consumer(
                builder: (context, ref, _) {
                  final month = ref.watch(effectiveMonthProvider);
                  return Text('month ${month.year}-${month.month}');
                },
              ),
            },
          ),
        ),
      ),
    );

    await mountShell(const ValueKey('first'));

    container.read(selectedMonthProvider.notifier).state = DateTime.utc(
      2019,
      3,
    );
    await tester.pumpAndSettle();
    expect(find.text('month 2019-3'), findsOneWidget);

    await mountShell(const ValueKey('rebuilt'));
    await tester.pumpAndSettle();

    expect(find.text('month 2019-3'), findsOneWidget);
  }, timeout: uiTestTimeout);

  group('stable mobile stack', () {
    Future<void> pushChild(
      WidgetTester tester,
      ShellDestination destination,
      ProviderContainer container,
    ) async {
      container.read(selectedDestinationProvider.notifier).state = destination;
      await tester.pumpAndSettle();
      final root = tester.element(find.text('${destination.name} probe'));
      Navigator.of(root).push(
        MaterialPageRoute<void>(
          builder: (_) => Text('${destination.name} child'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('nested routes in every destination survive a phone-open-'
        'phone round trip', (tester) async {
      final keys = {
        for (final destination in ShellDestination.values)
          destination: GlobalKey(),
      };
      final container = await _pumpBoundShell(
        tester,
        size: _compact,
        bodies: {
          for (final destination in ShellDestination.values)
            destination: (_) => _ProbeFlow(
              key: keys[destination],
              label: '${destination.name} probe',
            ),
        },
      );
      for (final destination in ShellDestination.values) {
        await pushChild(tester, destination, container);
      }

      Finder navOf(ShellDestination destination) => find.byElementPredicate(
        (element) =>
            element ==
            (keys[destination]!.currentState as _ProbeFlowState?)
                ?.navigatorContext,
        skipOffstage: false,
      );
      final flowStates = {
        for (final destination in keys.keys)
          destination: keys[destination]!.currentState,
      };
      final navStates = {
        for (final destination in keys.keys)
          destination: tester.state(navOf(destination)),
      };

      await _resize(tester, _openSized);
      expect(find.byKey(_openRailKey), findsOneWidget);
      await _resize(tester, _compact);
      expect(find.byKey(_phoneBarKey), findsOneWidget);

      for (final destination in keys.keys) {
        expect(
          identical(keys[destination]!.currentState, flowStates[destination]),
          isTrue,
          reason: '${destination.name} flow state',
        );
        expect(
          identical(tester.state(navOf(destination)), navStates[destination]),
          isTrue,
          reason: '${destination.name} navigator state',
        );
        expect(
          find.text('${destination.name} child', skipOffstage: false),
          findsOneWidget,
        );
      }

      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.overview;
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('overview child'), findsNothing);
      expect(find.text('overview probe'), findsOneWidget);
      expect(find.text('history child', skipOffstage: false), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('inactive destinations keep nested routes while open', (
      tester,
    ) async {
      final container = await _pumpBoundShell(tester, size: _compact);
      for (final destination in [
        ShellDestination.history,
        ShellDestination.money,
      ]) {
        await pushChild(tester, destination, container);
      }
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.overview;
      await tester.pumpAndSettle();

      await _resize(tester, _openSized);

      expect(find.text('overview probe'), findsOneWidget);
      expect(find.text('history child'), findsNothing);
      expect(find.text('history child', skipOffstage: false), findsOneWidget);
      expect(find.text('money child', skipOffstage: false), findsOneWidget);

      await _resize(tester, _compact);

      expect(find.text('history child', skipOffstage: false), findsOneWidget);
      expect(find.text('money child', skipOffstage: false), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('shell history keeps its flow on phone with no Overview back '
        'control', (tester) async {
      final historyFlowKey = GlobalKey();
      final entryIds = StringBuffer();
      final container = await _pumpBoundShell(
        tester,
        size: _openSized,
        bodies: {
          ..._probeBodies(),
          ShellDestination.history: (_) =>
              TransactionsFlow(key: historyFlowKey),
        },
        ledger: _ledgerWithEntry(entryIds),
      );
      container.read(selectedDestinationProvider.notifier).state =
          ShellDestination.history;
      await tester.pumpAndSettle();
      expect(find.text('Transactions'), findsOneWidget);
      final flowState = historyFlowKey.currentState;

      await _resize(tester, _compact);

      expect(find.text('Transactions'), findsOneWidget);
      expect(identical(historyFlowKey.currentState, flowState), isTrue);
      expect(find.byType(BackButton), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.history,
      );
      expect(find.text('Transactions'), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('Overview history request selects the retained History tab '
        'without pushing a route', (tester) async {
      final historyFlowKey = GlobalKey();
      final container = await _pumpBoundShell(
        tester,
        size: _compact,
        bodies: {
          ..._probeBodies(),
          ShellDestination.overview: (context) => OverviewFlow(
            onHistorySelected: () =>
                ProviderScope.containerOf(context)
                        .read(selectedDestinationProvider.notifier)
                        .state =
                    ShellDestination.history,
          ),
          ShellDestination.history: (_) =>
              TransactionsFlow(key: historyFlowKey),
        },
        ledger: Ledger(state: emptyState()),
        settleAnalysisCache: true,
      );
      final flowState = historyFlowKey.currentState;

      container.read(overviewViewModelProvider.notifier).requestHistory();
      await tester.pumpAndSettle();

      expect(
        container.read(selectedDestinationProvider),
        ShellDestination.history,
      );
      expect(find.text('Transactions'), findsOneWidget);
      expect(identical(historyFlowKey.currentState, flowState), isTrue);

      await _resize(tester, _openSized);
      await _resize(tester, _compact);

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    }, timeout: uiTestTimeout);
  });
}
