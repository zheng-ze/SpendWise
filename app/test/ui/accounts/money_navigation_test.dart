import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';

import '../../support/ui_test_timeout.dart';

void main() {
  testWidgets('scoped register source follows the live Navigator top route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final innerNavigatorKey = GlobalKey<NavigatorState>();
    NavigatorState moneyNavigator() {
      final navigator = navigatorKey.currentState;
      if (navigator == null) throw StateError('Money Navigator is unavailable');
      return navigator;
    }

    String? sourceId() => scopedRegisterSourceId(navigatorKey.currentState);

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

    expect(scopedRegisterSourceId(null), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) => route('Money root', null),
        ),
      ),
    );
    expect(sourceId(), isNull);

    final scopeA = route('Scope A', 'same-id');
    moneyNavigator().push<void>(scopeA);
    await tester.pumpAndSettle();
    expect(sourceId(), 'same-id');

    final scopeB = route('Scope B', 'same-id');
    moneyNavigator().push<void>(scopeB);
    await tester.pumpAndSettle();
    expect(sourceId(), 'same-id');

    moneyNavigator().pop();
    await tester.pumpAndSettle();
    expect(sourceId(), 'same-id');

    moneyNavigator().pop();
    await tester.pumpAndSettle();
    expect(sourceId(), isNull);

    final tagged = route('Tagged', 'account-id');
    moneyNavigator().push<void>(tagged);
    await tester.pumpAndSettle();
    expect(sourceId(), 'account-id');

    final untagged = route('Untagged', null);
    moneyNavigator().push<void>(untagged);
    await tester.pumpAndSettle();
    expect(sourceId(), isNull);

    moneyNavigator().removeRoute(untagged);
    await tester.pumpAndSettle();
    expect(sourceId(), 'account-id');

    final replaced = route('Replaced', 'replacement-id');
    moneyNavigator().replace(oldRoute: tagged, newRoute: replaced);
    await tester.pumpAndSettle();
    expect(sourceId(), 'replacement-id');

    final replacementUntagged = route('Replacement untagged', null);
    moneyNavigator().replace(oldRoute: replaced, newRoute: replacementUntagged);
    await tester.pumpAndSettle();
    expect(sourceId(), isNull);

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
    expect(sourceId(), 'outer-source');

    final innerNavigator = innerNavigatorKey.currentState;
    if (innerNavigator == null) {
      throw StateError('Inner Navigator is unavailable');
    }
    innerNavigator.push<void>(route('Inner route', null));
    await tester.pumpAndSettle();
    expect(sourceId(), 'outer-source');

    innerNavigator.pop();
    await tester.pumpAndSettle();
    expect(sourceId(), 'outer-source');

    await tester.pumpWidget(const SizedBox.shrink());
    expect(sourceId(), isNull);

    final recreatedNavigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: recreatedNavigatorKey,
          onGenerateRoute: (_) => route('Recreated root', null),
        ),
      ),
    );
    expect(scopedRegisterSourceId(recreatedNavigatorKey.currentState), isNull);
  }, timeout: uiTestTimeout);
}
