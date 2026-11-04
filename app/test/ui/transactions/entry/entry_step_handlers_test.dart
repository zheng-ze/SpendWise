import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/common/pickers/app_picker_sheet.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_step_handlers.dart';
import 'package:spendwise/ui/transactions/transactions_view_model.dart';

import '../../../support/picker_sheet_harness.dart';
import '../../../support/sheet_contract.dart';
import '../../../support/ui_test_timeout.dart';

const _openLabel = 'open category';

Future<List<ModalRoute<dynamic>>> _openCategoryPicker(
  WidgetTester tester, {
  required bool recordRoutes,
}) async {
  useSheetSize(tester, phoneTallSize);
  final routes = <ModalRoute<dynamic>>[];
  final launcher = Consumer(
    builder: (context, ref, _) => TextButton(
      onPressed: () => dispatchEntryFormStep(
        context,
        ref,
        null,
        PickCategoryRequested(),
        sheetPresentation: presentationFor(phoneTallSize),
        onPickerRouteCreated: recordRoutes ? routes.add : null,
      ),
      child: const Text(_openLabel),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ledgerProvider.overrideWithValue(Ledger())],
      child: MaterialApp(home: Scaffold(body: launcher)),
    ),
  );
  await tester.tap(find.text(_openLabel));
  await tester.pumpAndSettle();
  return routes;
}

void main() {
  testWidgets('reports the created picker route once', (tester) async {
    final routes = await _openCategoryPicker(tester, recordRoutes: true);

    expect(find.byType(AppPickerSheet), findsOneWidget);
    expect(routes, hasLength(1));
    expect(routes.single, isA<AppSheetRoute<dynamic>>());
  }, timeout: uiTestTimeout);

  testWidgets('opens the picker without a route callback', (tester) async {
    await _openCategoryPicker(tester, recordRoutes: false);

    expect(find.byType(AppPickerSheet), findsOneWidget);
  }, timeout: uiTestTimeout);
}
