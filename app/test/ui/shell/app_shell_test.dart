import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _compact = Size(400, 800);
const _wide = Size(1200, 900);

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  ShellLayoutMode layoutMode = ShellLayoutMode.phone,
  Map<ShellDestination, WidgetBuilder> bodies = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
        shellLayoutModeProvider.overrideWithValue(layoutMode),
      ],
      child: MaterialApp(home: AppShell(bodies: bodies)),
    ),
  );
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone mode uses a bottom bar with the four destinations', (
    tester,
  ) async {
    await _pumpShell(tester, size: _compact);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['Transactions', 'Stats', 'Accounts', 'Settings']);
  });

  testWidgets('system insets stay outside the bar pill', (tester) async {
    await _pumpShell(tester, size: _compact);

    final plain = tester.getSize(find.byType(NavigationBar)).height;

    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.getSize(find.byType(NavigationBar)).height, plain);
  });

  testWidgets('desktop mode uses a compact rail with the same destinations', (
    tester,
  ) async {
    await _pumpShell(tester, size: _wide, layoutMode: ShellLayoutMode.desktop);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    final labels = rail.destinations
        .map((d) => (d.label as Text).data)
        .toList();
    expect(labels, ['Transactions', 'Stats', 'Accounts', 'Settings']);
    expect(rail.extended, isFalse);
    expect(rail.labelType, NavigationRailLabelType.all);
  });

  for (final width in [320.0, 720.0, 1440.0]) {
    testWidgets(
      'phone mode keeps the bar at ${width.toInt()}px logical width',
      (tester) async {
        await _pumpShell(tester, size: Size(width, 800));

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      },
    );

    testWidgets(
      'desktop mode keeps the rail at ${width.toInt()}px logical width',
      (tester) async {
        await _pumpShell(
          tester,
          size: Size(width, 800),
          layoutMode: ShellLayoutMode.desktop,
        );

        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );
  }

  testWidgets('resizing across former thresholds switches no layout', (
    tester,
  ) async {
    await _pumpShell(tester, size: _compact);
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    for (final width in [680.0, 700.0, 720.0, 960.0, 1000.0, 1200.0]) {
      await _resize(tester, Size(width, 900));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    }
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('resizing a desktop shell switches no layout', (tester) async {
    await _pumpShell(tester, size: _wide, layoutMode: ShellLayoutMode.desktop);

    for (final width in [1200.0, 1000.0, 960.0, 720.0, 680.0, 320.0]) {
      await _resize(tester, Size(width, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    }
  });

  testWidgets('selecting a destination moves the bar selection', (
    tester,
  ) async {
    await _pumpShell(tester, size: _compact);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('a drilled-in destination keeps its stack across a switch', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: _compact,
      bodies: {
        ShellDestination.transactions: (context) => Navigator(
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

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('entry detail'), findsNothing);

    await tester.tap(find.text('Transactions'));
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
        ShellDestination.transactions: (context) => Navigator(
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
    expect(find.byType(NavigationBar), findsOneWidget);
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
              ShellDestination.transactions: (context) => Consumer(
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
