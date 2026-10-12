import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/settings_providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/common/app_sheet.dart';
import 'package:spendwise/ui/common/flow_base.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _compact = Size(400, 800);
const _wide = Size(1200, 900);

const _phoneBarKey = ValueKey('phone-bar');
const _sidebarKey = ValueKey('sidebar');

const _barLabels = ['Overview', 'Trends', 'Add', 'Money', 'Settings'];

class _ProbeFlow extends FlowBase<String> {
  const _ProbeFlow({required this.label});

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
  ShellDestination.trends: (context) => const _ProbeFlow(label: 'trends probe'),
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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
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
      child: MaterialApp(home: AppShell(bodies: bodies ?? _probeBodies())),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
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
  testWidgets('the shell opens on the overview destination', (tester) async {
    final container = await _pumpShell(tester, size: _compact);

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
    expect(find.text('overview probe'), findsOneWidget);
  });

  testWidgets('phone bar shows Overview, Trends, Add, Money, Settings in '
      'order with no History item', (tester) async {
    await _pumpShell(tester, size: _compact);

    expect(find.byKey(_phoneBarKey), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    _expectBarOrder(tester);
    expect(find.text('History'), findsNothing);
  });

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
  });

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
  });

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

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();

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

  testWidgets('Add from every phone destination opens the shared sheet and '
      'keeps the selection', (tester) async {
    final container = await _pumpShell(
      tester,
      size: _compact,
      ledger: _buildLedger(),
    );

    for (final destination in ['Overview', 'Trends', 'Money', 'Settings']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSheet), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSheet), findsNothing);
    }

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.settings,
    );
  });

  testWidgets('phone mounts no History slot while visiting every destination', (
    tester,
  ) async {
    await _pumpShell(tester, size: _compact);

    for (final destination in ['Trends', 'Money', 'Settings', 'Overview']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
    }

    expect(find.text('history probe', skipOffstage: false), findsNothing);
    expect(find.text('overview probe'), findsOneWidget);
  });

  testWidgets('the shell shows no header gear or Add FAB', (tester) async {
    await _pumpShell(tester, size: _compact);

    for (final destination in ['Overview', 'Trends', 'Money', 'Settings']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.settings), findsNothing);
    }
  });

  testWidgets('system insets stay outside the bar pill', (tester) async {
    await _pumpShell(tester, size: _compact);

    final plain = tester.getSize(find.byKey(_phoneBarKey)).height;

    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    await tester.pumpAndSettle();

    expect(find.byKey(_phoneBarKey), findsOneWidget);
    expect(tester.getSize(find.byKey(_phoneBarKey)).height, plain);
  });

  testWidgets('desktop sidebar shows the wordmark, destinations, Add entry '
      'and bottom Settings', (tester) async {
    await _pumpShell(tester, size: _wide, layoutMode: ShellLayoutMode.desktop);

    expect(find.byKey(_sidebarKey), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('SpendWise', findRichText: true), findsOneWidget);
    for (final label in [
      'Overview',
      'History',
      'Trends',
      'Money',
      'Settings',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Add entry'), findsOneWidget);

    final settingsDy = tester.getCenter(find.text('Settings')).dy;
    for (final label in ['Overview', 'History', 'Trends', 'Money']) {
      expect(tester.getCenter(find.text(label)).dy, lessThan(settingsDy));
    }
  });

  testWidgets('desktop History hosts its body with no phone back control', (
    tester,
  ) async {
    await _pumpShell(tester, size: _wide, layoutMode: ShellLayoutMode.desktop);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('history probe'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

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

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
  });

  for (final width in [320.0, 720.0, 1440.0]) {
    testWidgets(
      'phone mode keeps the bar at ${width.toInt()}px logical width',
      (tester) async {
        await _pumpShell(tester, size: Size(width, 800));

        expect(find.byKey(_phoneBarKey), findsOneWidget);
        expect(find.byKey(_sidebarKey), findsNothing);
      },
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
    );
  }

  testWidgets('resizing across former thresholds switches no layout', (
    tester,
  ) async {
    final container = await _pumpShell(tester, size: _compact);
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();

    for (final width in [680.0, 700.0, 720.0, 960.0, 1000.0, 1200.0]) {
      await _resize(tester, Size(width, 900));
      expect(find.byKey(_phoneBarKey), findsOneWidget);
      expect(find.byKey(_sidebarKey), findsNothing);
    }
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.trends,
    );
  });

  testWidgets('resizing a desktop shell switches no layout', (tester) async {
    await _pumpShell(tester, size: _wide, layoutMode: ShellLayoutMode.desktop);

    for (final width in [1200.0, 1000.0, 960.0, 720.0, 680.0, 320.0]) {
      await _resize(tester, Size(width, 900));
      expect(find.byKey(_sidebarKey), findsOneWidget);
      expect(find.byKey(_phoneBarKey), findsNothing);
    }
  });

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

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('entry detail'), findsNothing);

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('entry detail'), findsOneWidget);
    expect(find.text('open detail'), findsNothing);
  });

  testWidgets('a drilled-in destination keeps its stack across a resize', (
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

    await _resize(tester, const Size(1200, 900));

    expect(find.text('entry detail'), findsOneWidget);
    expect(find.byKey(_phoneBarKey), findsOneWidget);
  });

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
  });

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
    });

    testWidgets('Back at an active root preserves every stack', (tester) async {
      await pumpProbes(tester);
      await pushProbeChild(tester, 'hidden');

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('active'), findsOneWidget);
      expect(find.text('hidden', skipOffstage: false), findsOneWidget);
      expect(find.text('hidden child', skipOffstage: false), findsOneWidget);
    });

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
    });
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
  });
}
