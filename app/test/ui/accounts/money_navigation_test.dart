import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';

import '../../support/ui_test_timeout.dart';

void main() {
  testWidgets('Money observer follows route stack changes by route identity', (
    tester,
  ) async {
    final observer = MoneyNavigatorObserver();
    final navigatorKey = GlobalKey<NavigatorState>();
    final innerNavigatorKey = GlobalKey<NavigatorState>();
    NavigatorState moneyNavigator() {
      final navigator = navigatorKey.currentState;
      if (navigator == null) throw StateError('Money Navigator is unavailable');
      return navigator;
    }

    Route<void> route(String label, String? sourceId, {Widget? child}) =>
        MaterialPageRoute<void>(
          settings: sourceId == null
              ? RouteSettings(name: label)
              : MoneyTransactionsRouteSettings(
                  name: label,
                  preferredSourceId: sourceId,
                ),
          builder: (_) => Scaffold(body: child ?? Text(label)),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: navigatorKey,
          observers: [observer],
          onGenerateRoute: (_) => route('Money root', null),
        ),
      ),
    );
    expect(observer.sourceId, isNull);

    final scopeA = route('Scope A', 'same-id');
    moneyNavigator().push<void>(scopeA);
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'same-id');

    final scopeB = route('Scope B', 'same-id');
    moneyNavigator().push<void>(scopeB);
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'same-id');

    moneyNavigator().pop();
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'same-id');

    moneyNavigator().pop();
    await tester.pumpAndSettle();
    expect(observer.sourceId, isNull);

    final tagged = route('Tagged', 'account-id');
    moneyNavigator().push<void>(tagged);
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'account-id');

    final untagged = route('Untagged', null);
    moneyNavigator().push<void>(untagged);
    await tester.pumpAndSettle();
    expect(observer.sourceId, isNull);

    moneyNavigator().removeRoute(untagged);
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'account-id');

    final replaced = route('Replaced', 'replacement-id');
    moneyNavigator().replace(oldRoute: tagged, newRoute: replaced);
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'replacement-id');

    final replacementUntagged = route('Replacement untagged', null);
    moneyNavigator().replace(oldRoute: replaced, newRoute: replacementUntagged);
    await tester.pumpAndSettle();
    expect(observer.sourceId, isNull);

    final scopedWithInnerNavigator = route(
      'Scoped with inner navigator',
      'outer-source',
      child: Navigator(
        key: innerNavigatorKey,
        onGenerateRoute: (_) => route('Inner root', null),
      ),
    );
    moneyNavigator().replace(
      oldRoute: replacementUntagged,
      newRoute: scopedWithInnerNavigator,
    );
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'outer-source');

    final innerNavigator = innerNavigatorKey.currentState;
    if (innerNavigator == null) {
      throw StateError('Inner Navigator is unavailable');
    }
    innerNavigator.push<void>(route('Inner route', null));
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'outer-source');

    innerNavigator.pop();
    await tester.pumpAndSettle();
    expect(observer.sourceId, 'outer-source');

    await tester.pumpWidget(const SizedBox.shrink());
    expect(observer.sourceId, isNull);

    final recreatedNavigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: recreatedNavigatorKey,
          observers: [observer],
          onGenerateRoute: (_) => route('Recreated root', null),
        ),
      ),
    );
    expect(observer.sourceId, isNull);
  }, timeout: uiTestTimeout);
}
