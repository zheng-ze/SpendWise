import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';
import 'package:spendwise/ui/transactions/entry/add_amount_block.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

import 'new_entry_session_harness.dart';
import '../../../support/ui_test_timeout.dart';

const _missingId = 'd0000000-0000-0000-0000-00000000dead';
const _focusedUnderlineHeight = 2.0;

typedef _KindLook = ({
  EntryFormKind kind,
  String sign,
  Color Function(SpendWiseColors) tone,
});

final _looks = <_KindLook>[
  (kind: EntryFormKind.expense, sign: '-', tone: (c) => c.expense),
  (kind: EntryFormKind.income, sign: '+', tone: (c) => c.income),
  (kind: EntryFormKind.transfer, sign: '', tone: (c) => c.text),
];

SpendWiseColors _colorsOf(Brightness brightness) =>
    brightness == Brightness.dark
    ? SpendWiseColors.dark
    : SpendWiseColors.light;

Finder get _amountField => find.descendant(
  of: find.byType(AddAmountBlock),
  matching: find.byType(TextField),
);

Finder _signIn(String sign) =>
    find.descendant(of: find.byType(AddAmountBlock), matching: find.text(sign));

Finder _focusedUnderline(Color color) => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.color == color &&
      widget.constraints?.maxHeight == _focusedUnderlineHeight,
);

Future<void> _expectLook(
  WidgetTester tester,
  EntryHarness harness,
  Brightness brightness,
  _KindLook look,
) async {
  final colors = _colorsOf(brightness);
  harness.form.setKind(look.kind);
  harness.form.setAmount('42.50');
  await tester.pumpAndSettle();

  final field = tester.widget<TextField>(_amountField);
  expect(field.controller!.text, '42.50');
  expect(field.style!.color, look.tone(colors));
  expect(_signIn('-'), look.sign == '-' ? findsOneWidget : findsNothing);
  expect(_signIn('+'), look.sign == '+' ? findsOneWidget : findsNothing);
  expect(_focusedUnderline(colors.focus), findsOneWidget);
}

void _registerLookTests() {
  for (final brightness in Brightness.values) {
    for (final look in _looks) {
      _registerLookTest(brightness, look);
    }
  }
}

void _registerLookTest(Brightness brightness, _KindLook look) {
  final name = '${look.kind.name} look in ${brightness.name}';
  testWidgets(name, (tester) async {
    final theme = buildSpendWiseTheme(brightness);
    final harness = await pumpShell(tester, theme: theme);
    await openAdd(tester, harness);

    await _expectLook(tester, harness, brightness, look);
  }, timeout: uiTestTimeout);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _registerLookTests();

  group('display projection in the Add rows', () {
    testWidgets('a ledger rename updates the label and keeps the draft', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      harness.form.applyPickedSource(checkingId);
      await tester.pumpAndSettle();
      expect(find.text('Checking'), findsOneWidget);
      final before = harness.draft;

      harness.ledger.updateAccount(
        Account(id: checkingId, name: 'Everyday', type: AccountType.checking),
      );
      await tester.pumpAndSettle();

      expect(find.text('Everyday'), findsOneWidget);
      expect(harness.draft, before);
    }, timeout: uiTestTimeout);

    testWidgets('missing entities show the unavailable labels', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);

      harness.form.applyPickedSource(_missingId);
      harness.form.applyPickedCategory(_missingId);
      await tester.pumpAndSettle();

      expect(find.text('Unavailable account'), findsOneWidget);
      expect(find.text('Unavailable category'), findsOneWidget);
    }, timeout: uiTestTimeout);
  });
}
