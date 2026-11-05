import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/feedback/destructive_confirmation.dart';

import '../../../support/ui_test_timeout.dart';

const _hostLabel = 'host';
const _dialogTitle = 'Delete the thing?';
const _dialogBody = 'It will be gone.';
const _outsideTap = Offset(2, 2);

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Text(_hostLabel))),
  );
  return tester.element(find.text(_hostLabel));
}

void main() {
  testWidgets('Delete returns true', (tester) async {
    final context = await _pumpHost(tester);
    final future = showDestructiveConfirmation(
      context,
      title: _dialogTitle,
      body: _dialogBody,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await future, isTrue);
  }, timeout: uiTestTimeout);

  testWidgets('Cancel returns false', (tester) async {
    final context = await _pumpHost(tester);
    final future = showDestructiveConfirmation(
      context,
      title: _dialogTitle,
      body: _dialogBody,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await future, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('Back returns false', (tester) async {
    final context = await _pumpHost(tester);
    final future = showDestructiveConfirmation(
      context,
      title: _dialogTitle,
      body: _dialogBody,
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(await future, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('outside tap returns false', (tester) async {
    final context = await _pumpHost(tester);
    final future = showDestructiveConfirmation(
      context,
      title: _dialogTitle,
      body: _dialogBody,
    );
    await tester.pumpAndSettle();

    await tester.tapAt(_outsideTap);
    await tester.pumpAndSettle();

    expect(await future, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('returns only after the dialog route completed', (tester) async {
    final context = await _pumpHost(tester);
    var returned = false;
    showDestructiveConfirmation(
      context,
      title: _dialogTitle,
      body: _dialogBody,
    ).then((_) => returned = true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(returned, isFalse);

    await tester.pumpAndSettle();
    expect(returned, isTrue);
  }, timeout: uiTestTimeout);
}
