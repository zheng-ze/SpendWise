import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/common/sheets/sheet_session.dart';

import '../../../support/ui_test_timeout.dart';

const _completionTimeout = Duration(seconds: 5);

final _probeProvider = Provider<int>((ref) => 0);

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final session = SheetSession();

  NavigatorState get state => navigator.currentState!;

  AppSheetRoute<void> push() {
    final route = AppSheetRoute<void>(
      presentation: AppSheetPresentation.phone,
      builder: _sheetBody,
    );
    state.push(route);
    return route;
  }

  AppSheetRoute<void> pushSessionRoute() {
    final route = push();
    session.route = route;
    return route;
  }
}

Widget _sheetBody(BuildContext context) =>
    const AppSheet(header: Text('sheet'), body: Text('body'));

Future<_Harness> _pump(WidgetTester tester) async {
  final harness = _Harness();
  final app = MaterialApp(
    navigatorKey: harness.navigator,
    home: const Scaffold(body: Text('home')),
  );
  await tester.pumpWidget(ProviderScope(child: app));
  await tester.pumpAndSettle();
  return harness;
}

ProviderSubscription<int> _listen() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.listen(_probeProvider, (_, _) {});
}

void main() {
  testWidgets('dismiss pops the route when it is current', (tester) async {
    final harness = await _pump(tester);
    final route = harness.pushSessionRoute();
    await tester.pumpAndSettle();

    harness.session.dismiss();
    await tester.pumpAndSettle();

    await route.completed.timeout(_completionTimeout);
    expect(route.isActive, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets(
    'dismiss removes a covered route and leaves the covering route open',
    (tester) async {
      final harness = await _pump(tester);
      final route = harness.pushSessionRoute();
      final cover = harness.push();
      await tester.pumpAndSettle();

      harness.session.dismiss();
      await tester.pumpAndSettle();

      await route.completed.timeout(_completionTimeout);
      expect(route.isActive, isFalse);
      expect(cover.isActive, isTrue);
      expect(cover.isCurrent, isTrue);
    },
    timeout: uiTestTimeout,
  );

  testWidgets(
    'dismiss does nothing without a route or after the route is gone',
    (tester) async {
      final harness = await _pump(tester);
      harness.session.dismiss();
      final route = harness.pushSessionRoute();
      await tester.pumpAndSettle();
      harness.state.pop();
      await tester.pumpAndSettle();
      final bottom = harness.push();
      await tester.pumpAndSettle();

      harness.session.dismiss();
      await tester.pumpAndSettle();

      expect(route.isActive, isFalse);
      expect(bottom.isActive, isTrue);
    },
    timeout: uiTestTimeout,
  );

  testWidgets('retire removes the route after the frame and is idempotent', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final route = harness.pushSessionRoute();
    await tester.pumpAndSettle();

    harness.session.retire();
    expect(harness.session.retired, isTrue);
    expect(route.isActive, isTrue);
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(route.isActive, isFalse);

    final next = harness.push();
    await tester.pumpAndSettle();
    harness.session.route = next;
    harness.session.retire();
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(next.isActive, isTrue);
  }, timeout: uiTestTimeout);

  test('retire and end close the subscription', () {
    final retiring = SheetSession()..subscription = _listen();
    final ending = SheetSession()..subscription = _listen();
    final retiringSubscription = retiring.subscription!;
    final endingSubscription = ending.subscription!;

    retiring.retire();
    ending.end();

    expect(retiringSubscription.closed, isTrue);
    expect(endingSubscription.closed, isTrue);
    expect(retiring.subscription, isNull);
    expect(ending.subscription, isNull);
    expect(ending.retired, isFalse);
  });

  testWidgets('endWhenCompleted fires after the route completes', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final route = harness.push();
    await tester.pumpAndSettle();
    var ended = 0;
    final done = harness.session.endWhenCompleted(route, () => ended++);
    await tester.pump();
    expect(ended, 0);

    harness.state.pop();
    await tester.pumpAndSettle();
    await done.timeout(_completionTimeout);

    expect(ended, 1);
  }, timeout: uiTestTimeout);
}
