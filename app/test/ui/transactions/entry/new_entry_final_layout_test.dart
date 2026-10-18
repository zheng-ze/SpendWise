import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
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
  expect(
    rect.bottom,
    lessThanOrEqualTo(bounds.bottom + _boundsTolerance),
    reason: id,
  );
  expect(target.hitTestable(), findsOneWidget, reason: id);
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

Future<void> _editNoteWithKeyboard(WidgetTester tester) async {
  final note = _row('note');
  await _tapAndSettle(tester, note, 'note');
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
  await _settle(tester);
  await tester.enterText(note, _longNote);
  await _settle(tester);
  _expectClean(tester, 'note typing');
  await tester.ensureVisible(note);
  await _settle(tester);
  final visibleBottom = _windowSize.height - _keyboardHeight;
  final field = tester.getRect(note);
  expect(field.top, lessThan(visibleBottom));
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

Future<void> _applyDraft(EntryHarness harness, _Draft draft) async {
  final form = harness.form;
  form.setKind(draft.kind);
  form.setAmount(_longAmount);
  form.setName(_longName);
  form.applyPickedRecurrence(draft.recurrence);
  form.applyPickedSource(checkingId);
  if (draft.kind == EntryFormKind.transfer) {
    form.applyPickedDestination(checkingId);
  } else {
    form.applyPickedCategory(coffeeId);
  }
}

Future<void> _exerciseDraft(WidgetTester tester, _Draft draft) async {
  _useShellGeometry(tester);
  final harness = await pumpShell(tester, size: _windowSize, scanEnabled: true);
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

  await _openAndDismissPicker(tester, 'repeat', 'Every three months');
  if (draft.recurrence != null) {
    await _openAndDismissPicker(tester, 'ends', 'Choose date');
  }
  await _editNoteWithKeyboard(tester);
  await _tapAndSettle(tester, _row('analysis'), 'analysis');
  await _tapAndSettle(tester, _row('receipt'), 'receipt');
  await _reach(tester, find.text('Scan receipt'), 'camera action');
  await _reach(tester, find.text('Upload photo'), 'upload action');
  for (final label in ['Scan receipt', 'Upload photo']) {
    final action = find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<OutlinedButton>(),
    );
    expect(
      tester.getSize(action).height,
      lessThan(_maxActionHeight),
      reason: label,
    );
  }
  await _reach(tester, find.text('Save entry'), 'save');
  await tester.tap(find.text('Save entry'));
  await _settle(tester);
  _expectClean(tester, 'save tapped');
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
