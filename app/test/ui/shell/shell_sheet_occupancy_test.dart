import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/main.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_sheet_occupancy.dart';

import '../../support/ui_test_timeout.dart';

const _completionTimeout = Duration(seconds: 5);

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final builds = <bool>[];
  late Route<dynamic> shell;
  late ProviderContainer container;

  ShellSheetOccupancy get occupancy =>
      container.read(shellSheetOccupancyProvider);

  Widget buildHome(BuildContext context) {
    shell = ModalRoute.of(context)!;
    return Consumer(
      builder: (context, ref, _) {
        final covered = ref.watch(
          shellSheetOccupancyProvider.select((o) => o.isCovered(shell)),
        );
        builds.add(covered);
        return const Scaffold(body: Text('shell'));
      },
    );
  }

  AppSheetRoute<void> push({bool showNavigation = false}) {
    final route = AppSheetRoute<void>(
      presentation: AppSheetPresentation.phone,
      showShellNavigation: showNavigation,
      builder: _sheetBody,
    );
    navigator.currentState!.push(route);
    return route;
  }
}

Widget _sheetBody(BuildContext context) =>
    const AppSheet(header: Text('sheet'), body: Text('body'));

Future<_Harness> _pump(WidgetTester tester, {bool bound = true}) async {
  final harness = _Harness();
  final home = bound
      ? Builder(builder: harness.buildHome)
      : const Scaffold(body: Text('bare'));
  final app = MaterialApp(
    navigatorKey: harness.navigator,
    builder: bound ? buildShellAppContent : null,
    home: home,
  );
  if (bound) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    harness.container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: app),
    );
  } else {
    await tester.pumpWidget(app);
  }
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  test('occupancy state is local to its provider container', () {
    final first = ProviderContainer();
    final second = ProviderContainer();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final firstOccupancy = first.read(shellSheetOccupancyProvider.notifier);
    final secondOccupancy = second.read(shellSheetOccupancyProvider.notifier);
    expect(firstOccupancy, isNot(same(secondOccupancy)));
  });

  testWidgets(
    'creation reserves nothing; installation covers until last exit',
    (tester) async {
      final harness = await _pump(tester);
      final uninstalled = AppSheetRoute<void>(
        presentation: AppSheetPresentation.phone,
        builder: _sheetBody,
      );
      expect(harness.occupancy.hasSheets, isFalse);
      expect(harness.occupancy.isCovered(harness.shell), isFalse);
      expect(harness.occupancy.isCovered(null), isFalse);
      uninstalled.dispose();
      final first = harness.push(showNavigation: true);
      await tester.pumpAndSettle();
      expect(harness.occupancy.hasSheets, isTrue);
      expect(harness.occupancy.isCovered(harness.shell), isTrue);
      expect(harness.occupancy.suppressesShellNavigation, isTrue);
      final nested = harness.push();
      await tester.pumpAndSettle();
      expect(nested.nearestNonSheetPredecessor, same(harness.shell));
      harness.navigator.currentState!.pop();
      expect(harness.occupancy.hasSheets, isTrue);
      await tester.pumpAndSettle();
      await nested.completed.timeout(_completionTimeout);
      expect(harness.occupancy.isCovered(harness.shell), isTrue);
      harness.navigator.currentState!.pop();
      await tester.pump();
      expect(harness.occupancy.hasSheets, isTrue);
      await tester.pumpAndSettle();
      await first.completed.timeout(_completionTimeout);
      expect(harness.occupancy.hasSheets, isFalse);
      expect(harness.occupancy.isCovered(harness.shell), isFalse);
      expect(harness.occupancy.suppressesShellNavigation, isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'foreground page excludes shell coverage and removal updates it',
    (tester) async {
      final harness = await _pump(tester);
      final foreground = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('foreground')),
      );
      harness.navigator.currentState!.push(foreground);
      await tester.pumpAndSettle();
      final sheet = harness.push();
      await tester.pumpAndSettle();
      expect(harness.occupancy.hasSheets, isTrue);
      expect(harness.occupancy.isCovered(harness.shell), isFalse);
      expect(sheet.nearestNonSheetPredecessor, same(foreground));
      expect(harness.occupancy.suppressesShellNavigation, isFalse);
      harness.navigator.currentState!.removeRoute(foreground);
      await tester.pumpAndSettle();
      expect(harness.occupancy.isCovered(harness.shell), isTrue);
      harness.navigator.currentState!.removeRoute(sheet);
      await tester.pumpAndSettle();
      await sheet.completed.timeout(_completionTimeout);
      expect(harness.occupancy.hasSheets, isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('removing a parent sheet preserves nested shell coverage', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final first = harness.push(showNavigation: true);
    await tester.pumpAndSettle();
    final nested = harness.push();
    await tester.pumpAndSettle();
    harness.navigator.currentState!.removeRoute(first);
    await tester.pumpAndSettle();
    await first.completed.timeout(_completionTimeout);
    expect(harness.occupancy.isCovered(harness.shell), isTrue);
    expect(harness.occupancy.suppressesShellNavigation, isFalse);
    expect(nested.nearestNonSheetPredecessor, same(harness.shell));
    harness.navigator.currentState!.removeRoute(nested);
    await tester.pumpAndSettle();
    await nested.completed.timeout(_completionTimeout);
    expect(harness.occupancy.hasSheets, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets(
    'completion continuation installs next sheet before restoration',
    (tester) async {
      final harness = await _pump(tester);
      final first = harness.push();
      await tester.pumpAndSettle();
      harness.builds.clear();
      final next = first.completed.then((_) => harness.push());
      harness.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      final second = await next.timeout(_completionTimeout);
      expect(harness.occupancy.hasSheets, isTrue);
      expect(harness.builds, isNotEmpty);
      expect(harness.builds, everyElement(isTrue));
      harness.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await second.completed.timeout(_completionTimeout);
      expect(harness.builds.last, isFalse);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'navigator teardown releases occupancy without late notifications',
    (tester) async {
      final harness = await _pump(tester);
      final sheet = harness.push();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await sheet.completed.timeout(_completionTimeout);
      expect(harness.occupancy.hasSheets, isFalse);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'bare MaterialApp sheet returns a result without a provider scope',
    (tester) async {
      final harness = await _pump(tester, bound: false);
      final navigator = harness.navigator.currentState!;
      final result = showAppSheet<int>(
        navigator.overlay!.context,
        presentation: AppSheetPresentation.phone,
        builder: _sheetBody,
      );
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
      navigator.pop(7);
      await tester.pumpAndSettle();
      expect(await result.timeout(_completionTimeout), 7);
      expect(tester.takeException(), isNull);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('production MaterialApp initializes route coverage', (
    tester,
  ) async {
    final phase = Failed(StateError('fixture'));
    final scope = ProviderScope(
      overrides: [appPhaseProvider.overrideWithValue(phase)],
      child: const SpendWiseApp(),
    );
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final sheet = AppSheetRoute<void>(
      presentation: AppSheetPresentation.phone,
      builder: _sheetBody,
    );
    navigator.push(sheet);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(navigator.context);
    final occupancy = container.read(shellSheetOccupancyProvider);
    final predecessor = sheet.nearestNonSheetPredecessor;
    expect(predecessor, isNotNull);
    expect(occupancy.isCovered(predecessor), isTrue);
    navigator.pop();
    await tester.pumpAndSettle();
    await sheet.completed.timeout(_completionTimeout);
    await tester.pump();
    expect(container.read(shellSheetOccupancyProvider).hasSheets, isFalse);
  }, timeout: uiTestTimeout);
}
