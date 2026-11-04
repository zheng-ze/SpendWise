import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/feedback/async_value_view.dart';
import 'package:spendwise/ui/common/feedback/load_error_view.dart';

import '../../../support/ui_test_timeout.dart';

const _dataKey = Key('data');
const _failure = 'Data unavailable';

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<int> value, {
  VoidCallback? onRetry,
}) {
  final view = AsyncValueView<int>(
    value: value,
    onRetry: onRetry ?? () {},
    data: (number) => Text('$number', key: _dataKey),
  );
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
}

void main() {
  testWidgets('error state shows the message and Retry calls onRetry', (
    tester,
  ) async {
    var retries = 0;
    await _pump(
      tester,
      AsyncError<int>(Exception(_failure), StackTrace.empty),
      onRetry: () => retries += 1,
    );

    expect(find.textContaining(_failure), findsOneWidget);
    expect(find.byKey(_dataKey), findsNothing);
    await tester.tap(find.text(loadErrorRetryLabel));
    expect(retries, 1);
  }, timeout: uiTestTimeout);

  testWidgets('data state builds the child', (tester) async {
    await _pump(tester, const AsyncData(7));

    expect(find.text('7'), findsOneWidget);
    expect(find.text(loadErrorRetryLabel), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('loading state without a value renders nothing', (tester) async {
    await _pump(tester, const AsyncLoading<int>());

    expect(find.byKey(_dataKey), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(loadErrorRetryLabel), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);
}
