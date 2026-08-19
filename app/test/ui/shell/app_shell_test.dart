import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/layout_breakpoints.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _compact = Size(400, 800);
const _wide = Size(1200, 900);

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  Map<ShellDestination, WidgetBuilder> bodies = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: AppShell(bodies: bodies)),
    ),
  );
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact width uses a bottom bar with the four destinations', (
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

  testWidgets('wide width uses a rail with the same destinations', (
    tester,
  ) async {
    await _pumpShell(tester, size: _wide);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    final labels = rail.destinations
        .map((d) => (d.label as Text).data)
        .toList();
    expect(labels, ['Transactions', 'Stats', 'Accounts', 'Settings']);
  });

  testWidgets('switching destinations swaps the visible body', (tester) async {
    await _pumpShell(tester, size: _compact);

    expect(find.text('Transactions'), findsWidgets);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
  });

  testWidgets('a drilled-in destination keeps its stack across a switch', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: _compact,
      bodies: {
        ShellDestination.transactions: (context) => Builder(
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

  testWidgets('a shell rebuild keeps a non-current selected month', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = _compact;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The month is read through a widget, not through the container, so a shell
    // holding its own copy shows a stale value here rather than passing.
    Future<void> mountShell(Key key) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppShell(
            key: key,
            bodies: {
              ShellDestination.transactions: (context) => Consumer(
                builder: (context, ref, _) {
                  final month = ref.watch(selectedMonthProvider);
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

    // A changed key discards the whole shell subtree, which is what a month
    // held in widget state would not survive.
    await mountShell(const ValueKey('rebuilt'));
    await tester.pumpAndSettle();

    expect(find.text('month 2019-3'), findsOneWidget);
  });

  testWidgets(
    'shrinking into the dead zone between thresholds stays in rail mode',
    (tester) async {
      await _pumpShell(tester, size: _wide);
      expect(find.byType(NavigationRail), findsOneWidget);

      // Between railExit and railEnter: still rail, because the shell was
      // already in rail mode before crossing into the dead zone.
      await _resize(
        tester,
        Size(
          (LayoutBreakpoints.railEnter + LayoutBreakpoints.railExit) / 2,
          900,
        ),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await _resize(tester, Size(LayoutBreakpoints.railExit - 1, 900));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    },
  );

  testWidgets(
    'growing into the dead zone between thresholds stays in bottom nav mode',
    (tester) async {
      await _pumpShell(tester, size: _compact);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Between railExit and railEnter: still bottom nav, because the shell
      // was already in bottom-nav mode before crossing into the dead zone.
      await _resize(
        tester,
        Size(
          (LayoutBreakpoints.railEnter + LayoutBreakpoints.railExit) / 2,
          900,
        ),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      await _resize(tester, Size(LayoutBreakpoints.railEnter + 1, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets('a rail above the extended breakpoint is extended', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: Size(LayoutBreakpoints.extendedRailEnter + 100, 900),
    );

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('a rail between the rail and extended breakpoints is compact', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: Size(
        (LayoutBreakpoints.railEnter + LayoutBreakpoints.extendedRailEnter) / 2,
        900,
      ),
    );

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });
}
