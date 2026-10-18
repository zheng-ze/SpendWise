import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/inputs/number_pad.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/transactions/entry/add_amount_block.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_scan_flow.dart';
import 'package:spendwise/ui/common/inputs/segmented_control.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

import '../../../support/add_sheet_dismiss.dart';
import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

const _windowSize = Size(600, 480);
const _textScale = 1.5;
const _sheetWidth = 300.0;
const _contentWidth = 202.0;
const _formEdgeWidth = 1.0;
const _contentLeftInset = 16.0;
const _contentRightInset = 82.0;
const _maxActionHeight = 120.0;
const _keyboardHeight = 200.0;
const _frameStep = Duration(milliseconds: 16);
const _homeId = 'a0000000-0000-0000-0000-0000000000a1';
const _savingsId = 'a0000000-0000-0000-0000-0000000000a2';
const _expenseCategoryId = 'c0000000-0000-0000-0000-0000000000e1';
const _incomeCategoryId = 'c0000000-0000-0000-0000-0000000000e2';
const _longAccount = 'Household joint savings and everyday checking account';
const _longCategory = 'Groceries and household supplies for the whole family';
final _endDate = DateTime.utc(2027, 12, 31);
const _tallTargetDivisor = 3;
const _cornerProbe = 2.0;
const _boundsTolerance = 0.5;
const _longAmount = '1234567.89';
const _longName =
    'Household joint savings and everyday checking account top-up';
const _longNote =
    'Reimbursable team lunch with the whole project group\nreceipt pending';

typedef _Draft = ({
  String label,
  EntryFormKind kind,
  RecurrenceFrequency? recurrence,
});

const _drafts = <_Draft>[
  (label: 'expense', kind: EntryFormKind.expense, recurrence: null),
  (
    label: 'recurring expense',
    kind: EntryFormKind.expense,
    recurrence: RecurrenceFrequency.monthly,
  ),
  (label: 'income', kind: EntryFormKind.income, recurrence: null),
  (
    label: 'recurring income',
    kind: EntryFormKind.income,
    recurrence: RecurrenceFrequency.weekly,
  ),
  (label: 'transfer', kind: EntryFormKind.transfer, recurrence: null),
  (
    label: 'recurring transfer',
    kind: EntryFormKind.transfer,
    recurrence: RecurrenceFrequency.yearly,
  ),
];

Finder _row(String key) => find.byKey(ValueKey('new-entry-$key'));

void _useShellGeometry(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = _textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.view.resetViewInsets);
}

void _expectClean(WidgetTester tester, String reason) {
  expect(tester.takeException(), isNull, reason: reason);
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(_frameStep);

void _expectInside(WidgetTester tester, Finder target, Rect bounds, String id) {
  final rect = tester.getRect(target);
  expect(
    rect.left,
    greaterThanOrEqualTo(bounds.left - _boundsTolerance),
    reason: id,
  );
  expect(
    rect.right,
    lessThanOrEqualTo(bounds.right + _boundsTolerance),
    reason: id,
  );
  expect(
    rect.top,
    greaterThanOrEqualTo(bounds.top - _boundsTolerance),
    reason: id,
  );
  final tall = rect.height > bounds.height / _tallTargetDivisor;
  if (!tall) {
    expect(
      rect.bottom,
      lessThanOrEqualTo(bounds.bottom + _boundsTolerance),
      reason: id,
    );
    expect(target.hitTestable(), findsOneWidget, reason: id);
    return;
  }
  final corner = rect.topLeft + const Offset(_cornerProbe, _cornerProbe);
  final path = tester
      .hitTestOnBinding(corner)
      .path
      .map((entry) => entry.target);
  expect(path, contains(tester.renderObject(target)), reason: id);
}

Future<void> _reach(WidgetTester tester, Finder target, String id) async {
  await tester.ensureVisible(target);
  await _settle(tester);
  _expectClean(tester, id);
  final sheet = tester.getRect(find.byType(AppSheet));
  final content = Rect.fromLTRB(
    sheet.left + _contentLeftInset,
    sheet.top,
    sheet.right - _contentRightInset,
    sheet.bottom,
  );
  _expectInside(tester, target, content, id);
}

Future<void> _tapAndSettle(
  WidgetTester tester,
  Finder target,
  String id,
) async {
  await _reach(tester, target, id);
  await tester.tap(target);
  await _settle(tester);
  _expectClean(tester, id);
}

Future<void> _openAndDismissPicker(
  WidgetTester tester,
  String key,
  String optionText,
) async {
  await _tapAndSettle(tester, _row(key), key);
  expect(find.text(optionText), findsOneWidget, reason: key);
  _expectClean(tester, key);
  await dismissAddSheet(tester);
  _expectClean(tester, '$key dismissed');
}

Rect _lastLineCaret(WidgetTester tester) {
  final editable = tester.state<EditableTextState>(
    find.descendant(of: _row('note'), matching: find.byType(EditableText)),
  );
  final render = editable.renderEditable;
  final end = TextPosition(offset: editable.textEditingValue.text.length);
  final local = render.getLocalRectForCaret(end);
  return Rect.fromPoints(
    render.localToGlobal(local.topLeft),
    render.localToGlobal(local.bottomRight),
  );
}

Future<void> _editNoteWithKeyboard(WidgetTester tester) async {
  final note = _row('note');
  await _tapAndSettle(tester, note, 'note');
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
  await _settle(tester);
  await tester.enterText(note, _longNote);
  await _settle(tester);
  _expectClean(tester, 'note typing');
  final visibleBottom = _windowSize.height - _keyboardHeight;
  final sheetTop = tester.getRect(find.byType(AppSheet)).top;
  final caret = _lastLineCaret(tester);
  expect(caret.bottom, lessThanOrEqualTo(visibleBottom));
  expect(caret.top, greaterThanOrEqualTo(sheetTop));
  expect(find.text('Save entry').hitTestable(), findsOneWidget);
  expect(
    tester.getRect(find.text('Save entry')).bottom,
    lessThanOrEqualTo(visibleBottom),
  );
  tester.view.resetViewInsets();
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester);
  _expectClean(tester, 'note closed');
}

Future<void> _reopenAmountKeepingDraft(
  WidgetTester tester,
  EntryHarness harness,
  _Draft draft,
) async {
  await _tapAndSettle(tester, find.byType(AddAmountBlock), 'amount');
  final state = _formState(harness);
  expect(find.byType(NumberPad), findsOneWidget);
  expect(state.amountText, _longAmount);
  expect(state.nameText, _longName);
  expect(state.noteText, _longNote);
  expect(state.recurrence, draft.recurrence);
  expect(state.sourceId, _homeId);
  expect(
    state.destinationId,
    draft.kind == EntryFormKind.transfer ? _savingsId : null,
  );
  expect(state.categoryId, _categoryFor(draft.kind));
  if (draft.recurrence != null) expect(state.endDate, _endDate);
}

EntryFormViewState _formState(EntryHarness harness) =>
    harness.container.read(entryFormViewModelProvider(null)).value!;

String? _categoryFor(EntryFormKind kind) => switch (kind) {
  EntryFormKind.expense => _expenseCategoryId,
  EntryFormKind.income => _incomeCategoryId,
  EntryFormKind.transfer => null,
};

HookedLedger _finalLedger() {
  final home = Account(
    id: _homeId,
    name: _longAccount,
    type: AccountType.checking,
  );
  final savings = Account(
    id: _savingsId,
    name: '$_longAccount reserve',
    type: AccountType.savings,
  );
  final expense = TransactionCategory(
    id: _expenseCategoryId,
    name: _longCategory,
    kind: CategoryKind.expense,
    colorHex: '#FF0000',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_cafe',
  );
  final income = TransactionCategory(
    id: _incomeCategoryId,
    name: '$_longCategory income',
    kind: CategoryKind.income,
    colorHex: '#00AA00',
    includeInAnalysis: true,
    parentID: null,
    symbol: 'local_cafe',
  );
  return HookedLedger(
    state: LedgerState(
      moneySources: {
        home.id: MoneySource.account(home),
        savings.id: MoneySource.account(savings),
      },
      categories: {expense.id: expense, income.id: income},
    ),
  );
}

Future<void> _applyDraft(EntryHarness harness, _Draft draft) async {
  final form = harness.form;
  form.setKind(draft.kind);
  form.setAmount(_longAmount);
  form.setName(_longName);
  form.applyPickedRecurrence(draft.recurrence);
  if (draft.recurrence != null) form.applyPickedEndDate(_endDate);
  form.applyPickedSource(_homeId);
  if (draft.kind == EntryFormKind.transfer) {
    form.applyPickedDestination(_savingsId);
  } else {
    form.applyPickedCategory(_categoryFor(draft.kind));
  }
}

Future<void> _reachPickerRows(WidgetTester tester, _Draft draft) async {
  final transfer = draft.kind == EntryFormKind.transfer;
  for (final key in transfer ? ['from', 'to'] : ['category', 'account']) {
    await _reach(tester, _row(key), key);
  }
  if (draft.recurrence == null) return;
  await _reach(tester, _row('ends'), 'ends');
  expect(find.text(formatEntryDate(_endDate)), findsOneWidget);
}

Future<void> _useReceiptActions(
  WidgetTester tester,
  EntryHarness harness,
) async {
  harness.faults.swallowScans = true;
  await _tapAndSettle(tester, _row('receipt'), 'receipt');
  for (final label in ['Scan receipt', 'Upload photo']) {
    final action = find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<OutlinedButton>(),
    );
    await _reach(tester, find.text(label), label);
    expect(
      tester.getSize(action).height,
      lessThan(_maxActionHeight),
      reason: label,
    );
    await tester.tap(find.text(label));
    await _settle(tester);
    _expectClean(tester, label);
  }
  expect(harness.faults.scans, [
    ReceiptScanSource.camera,
    ReceiptScanSource.gallery,
  ]);
}

Future<void> _saveAndExpectEntry(
  WidgetTester tester,
  EntryHarness harness,
  _Draft draft,
) async {
  await _reach(tester, find.text('Save entry'), 'save');
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Save entry'),
  );
  expect(button.onPressed, isNotNull, reason: draft.label);
  await tester.tap(find.text('Save entry'));
  await _settle(tester);
  _expectClean(tester, 'save tapped');
  final state = harness.ledger.state;
  expect(find.byType(AppSheet), findsNothing);
  expect(harness.recorder.sheets, isEmpty);
  expect(state.plans, hasLength(draft.recurrence == null ? 0 : 1));
  expect(state.entries, isNotEmpty);
}

Future<void> _exerciseDraft(WidgetTester tester, _Draft draft) async {
  _useShellGeometry(tester);
  final harness = await pumpShell(
    tester,
    size: _windowSize,
    scanEnabled: true,
    entryLedger: _finalLedger(),
  );
  await openAdd(tester, harness);
  final sheet = tester.getRect(find.byType(AppSheet));
  expect(sheet.left, _windowSize.width / 2);
  expect(sheet.width, _sheetWidth);
  final kind = tester.getRect(find.byType(SegmentedControl<EntryFormKind>));
  expect(kind.right, _windowSize.width - _contentRightInset);
  expect(kind.width, _contentWidth - _formEdgeWidth);

  await _applyDraft(harness, draft);
  await _settle(tester);
  _expectClean(tester, draft.label);

  await _reachPickerRows(tester, draft);
  await _openAndDismissPicker(tester, 'repeat', 'Every three months');
  if (draft.recurrence != null) {
    await _openAndDismissPicker(tester, 'ends', 'Choose date');
  }
  await _editNoteWithKeyboard(tester);
  await _reopenAmountKeepingDraft(tester, harness, draft);
  await _tapAndSettle(tester, _row('analysis'), 'analysis');
  await _useReceiptActions(tester, harness);
  await _saveAndExpectEntry(tester, harness, draft);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('final Add form at 600 x 480, 202 dp content and 1.5x text', () {
    for (final draft in _drafts) {
      testWidgets('a ${draft.label} stays reachable and unclipped', (
        tester,
      ) async {
        await _exerciseDraft(tester, draft);
      }, timeout: uiTestTimeout);
    }
  });
}
