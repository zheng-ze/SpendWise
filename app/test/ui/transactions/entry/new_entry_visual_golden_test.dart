import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

import 'new_entry_session_harness.dart';

const _phoneWindow = Size(320, 760);
const _keyboardHeight = 260.0;
const _savingsId = 'a0000000-0000-0000-0000-000000000002';
const _salaryId = 'c0000000-0000-0000-0000-000000000002';
const _materialIconsPath =
    'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
const _fontAssets = ['Regular', 'Medium', 'SemiBold', 'Bold'];
const _frames = [
  (kind: EntryFormKind.expense, amount: '42.50', name: 'FairPrice groceries'),
  (kind: EntryFormKind.income, amount: '3200.00', name: 'Monthly salary'),
  (kind: EntryFormKind.transfer, amount: '500.00', name: 'To savings'),
];

typedef _Frame = ({EntryFormKind kind, String amount, String name});

Future<void> _loadFonts() async {
  final loader = FontLoader('InstrumentSans');
  for (final weight in _fontAssets) {
    loader.addFont(
      rootBundle.load(
        'assets/fonts/instrument_sans/InstrumentSans-$weight.ttf',
      ),
    );
  }
  await loader.load();
  final iconBytes = File(
    '${Platform.environment['FLUTTER_ROOT']}/$_materialIconsPath',
  ).readAsBytesSync();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(iconBytes)));
  await icons.load();
  EditableText.debugDeterministicCursor = true;
}

void _seedLedger(EntryHarness harness) {
  harness.ledger.updateAccount(
    Account(id: checkingId, name: 'DBS Checking', type: AccountType.checking),
  );
  harness.ledger.addAccount(
    Account(id: _savingsId, name: 'OCBC Savings', type: AccountType.savings),
  );
  harness.ledger.addCategory(
    TransactionCategory(
      id: _salaryId,
      name: 'Salary',
      kind: CategoryKind.income,
      colorHex: '#28684F',
      includeInAnalysis: true,
      parentID: null,
      symbol: 'attach_money',
    ),
  );
}

Future<void> _renderFrame(
  WidgetTester tester,
  _Frame frame,
  Brightness brightness, {
  bool keyboard = false,
}) async {
  final harness = await pumpShell(
    tester,
    size: _phoneWindow,
    theme: buildSpendWiseTheme(brightness),
  );
  _seedLedger(harness);
  await openAdd(tester, harness);
  harness.form.setKind(frame.kind);
  harness.form.setAmount(frame.amount);
  harness.form.setName(frame.name);
  harness.form.applyPickedDate(DateTime.utc(2026, 10, 3));
  harness.form.applyPickedSource(checkingId);
  harness.form.applyPickedDestination(
    frame.kind == EntryFormKind.transfer ? _savingsId : null,
  );
  harness.form.applyPickedCategory(
    frame.kind == EntryFormKind.income ? _salaryId : coffeeId,
  );
  await tester.pumpAndSettle();
  if (keyboard) await _focusName(tester);
  final surface = keyboard ? 'keyboard' : 'pad';
  final path = 'goldens/add-${frame.kind.name}-$surface-${brightness.name}.png';
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
  expect(tester.takeException(), isNull);
}

Future<void> _focusName(WidgetTester tester) async {
  await tester.tap(find.byType(TextField).at(1));
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
  await tester.pumpAndSettle();
}

void _registerFrame(_Frame frame) {
  for (final brightness in Brightness.values) {
    testWidgets('${frame.kind.name} pad ${brightness.name}', (tester) async {
      await _renderFrame(tester, frame, brightness);
    });
  }
}

void _registerKeyboard(Brightness brightness) {
  testWidgets('expense Name keyboard ${brightness.name}', (tester) async {
    await _renderFrame(tester, _frames.first, brightness, keyboard: true);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  tearDownAll(() => EditableText.debugDeterministicCursor = false);
  for (final frame in _frames) {
    _registerFrame(frame);
  }
  for (final brightness in Brightness.values) {
    _registerKeyboard(brightness);
  }
}
