import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/format/date_format.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/entry/fields/entry_fields.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_rows.dart';
import 'package:spendwise/ui/transactions/entry/steps/entry_form_logic.dart';

import '../../../support/ui_test_timeout.dart';

const _normalWidth = 400.0;
const _narrowWidth = 202.0;
const _stackedWidth = 110.0;
const _largeText = 1.5;
const _labelSize = 12.0;
const _keypadPaddingSaving = 4.0;
const _focusUnderline = 2.0;
const _hint = 'Saving creates a plan. Review it in Money, Plans.';
const _stripHeight = 40.0;
const _longValue = 'Household joint savings and everyday checking account';
final _entryDate = DateTime.utc(2026, 10, 16);
final _endDate = DateTime.utc(2027, 1, 16);

class _RecordingViewModel implements EntryFormViewModel {
  final calls = <Symbol>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
    return null;
  }
}

EntryFormViewState _state({
  EntryFormKind kind = EntryFormKind.expense,
  RecurrenceFrequency? recurrence,
  bool hasEndDate = false,
  bool includeInAnalysis = true,
}) {
  return EntryFormViewState(
    mode: EntryFormMode.newEntry,
    kind: kind,
    amountText: '',
    nameText: '',
    date: _entryDate,
    sourceId: null,
    destinationId: null,
    categoryId: null,
    includeInAnalysis: includeInAnalysis,
    recurrence: recurrence,
    hasEndDate: hasEndDate,
    endDate: _endDate,
    isSystemEntry: false,
    entryId: null,
  );
}

const _blankDisplay = EntryFormDisplay(
  sourceLabel: null,
  destinationLabel: null,
  categoryLabel: null,
);

const _longDisplay = EntryFormDisplay(
  sourceLabel: _longValue,
  destinationLabel: _longValue,
  categoryLabel: _longValue,
);

class _Fixture {
  _Fixture();

  final viewModel = _RecordingViewModel();
  final nameController = TextEditingController();
  final nameFocus = FocusNode();
  final nameGroupId = Object();
  final noteController = TextEditingController();
  final noteFocus = FocusNode();
  final noteGroupId = Object();

  void dispose() {
    nameController.dispose();
    nameFocus.dispose();
    noteController.dispose();
    noteFocus.dispose();
  }

  Widget rows(
    EntryFormViewState state,
    EntryFormDisplay display, {
    bool keypad = false,
    VoidCallback? onReceiptTap,
    Widget? receiptStrip,
  }) {
    return NewEntryRows(
      viewModel: viewModel,
      state: state,
      display: display,
      nameController: nameController,
      nameFocus: nameFocus,
      nameGroupId: nameGroupId,
      noteController: noteController,
      noteFocus: noteFocus,
      noteGroupId: noteGroupId,
      keypad: keypad,
      onOutsideDown: (_) {},
      onOutsideUp: (node, _) => node.unfocus(),
      onReceiptTap: onReceiptTap,
      receiptStrip: receiptStrip,
    );
  }
}

TransitionBuilder _textScaled(double scale) {
  return (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  );
}

Future<_Fixture> _pump(
  WidgetTester tester,
  EntryFormViewState state, {
  EntryFormDisplay display = _blankDisplay,
  double width = _normalWidth,
  double textScale = 1.0,
  bool keypad = false,
  VoidCallback? onReceiptTap,
  Widget? receiptStrip,
}) async {
  final fixture = _Fixture();
  addTearDown(fixture.dispose);
  final content = fixture.rows(
    state,
    display,
    keypad: keypad,
    onReceiptTap: onReceiptTap,
    receiptStrip: receiptStrip,
  );
  final body = SingleChildScrollView(
    child: SizedBox(width: width, child: content),
  );
  await tester.pumpWidget(
    MaterialApp(
      builder: _textScaled(textScale),
      home: Scaffold(body: body),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

Finder _row(String key) => find.byKey(ValueKey('new-entry-$key'));

void main() {
  group('row order', () {
    testWidgets(
      'an expense lists its rows in order with Note before Include in analysis',
      (tester) async {
        await _pump(tester, _state());

        final labels = [
          'Name',
          'Category',
          'Account',
          'Date',
          'Repeat',
          'Note',
          'Include in analysis',
        ];
        final tops = [for (final label in labels) _top(tester, label)];
        expect(tops, orderedEquals([...tops]..sort()));
        expect(find.byType(EntryRowDivider), findsNWidgets(labels.length - 1));
        expect(find.text('Ends'), findsNothing);
        expect(find.text(_hint), findsNothing);
      },
      timeout: uiTestTimeout,
    );

    testWidgets('a transfer swaps Category and Account for From and To', (
      tester,
    ) async {
      await _pump(tester, _state(kind: EntryFormKind.transfer));

      expect(_top(tester, 'From'), lessThan(_top(tester, 'To')));
      expect(_top(tester, 'To'), lessThan(_top(tester, 'Date')));
      expect(find.text('Category'), findsNothing);
      expect(find.text('Account'), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets(
      'a recurring draft shows Ends and the hint after the last row',
      (tester) async {
        await _pump(tester, _state(recurrence: RecurrenceFrequency.monthly));

        expect(_top(tester, 'Repeat'), lessThan(_top(tester, 'Ends')));
        expect(_top(tester, 'Ends'), lessThan(_top(tester, 'Note')));
        expect(
          _top(tester, 'Note'),
          lessThan(_top(tester, 'Include in analysis')),
        );
        expect(
          _top(tester, _hint),
          greaterThan(_top(tester, 'Include in analysis')),
        );
        expect(find.byType(EntryRowDivider), findsNWidgets(7));
        final hint = tester.widget<Text>(find.text(_hint));
        expect(hint.style?.fontSize, 10);
        expect(hint.style?.height, 1.4);
      },
      timeout: uiTestTimeout,
    );
  });

  group('row values', () {
    testWidgets('blank selections show Choose and Select with an empty Name', (
      tester,
    ) async {
      final fixture = await _pump(tester, _state());

      expect(find.text('Choose'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Does not repeat'), findsOneWidget);
      expect(fixture.nameController.text, isEmpty);
      expect(fixture.noteController.text, isEmpty);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('Repeat and Ends show the frequency and Never or the date', (
      tester,
    ) async {
      await _pump(tester, _state(recurrence: RecurrenceFrequency.biweekly));
      expect(find.text('Every two weeks'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);

      await _pump(
        tester,
        _state(recurrence: RecurrenceFrequency.yearly, hasEndDate: true),
      );
      expect(find.text('Every year'), findsOneWidget);
      expect(find.text(formatEntryDate(_endDate)), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('labels and values use the reference styles and chevrons', (
      tester,
    ) async {
      await _pump(tester, _state(), display: _longDisplay);

      final label = tester.widget<Text>(find.text('Date'));
      expect(label.style?.fontSize, _labelSize);
      expect(label.style?.color, SpendWiseColors.light.subtext);
      final value = find.text(formatEntryDate(_entryDate));
      final style = DefaultTextStyle.of(tester.element(value)).style;
      expect(style.fontSize, _labelSize);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.color, SpendWiseColors.light.text);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
    }, timeout: uiTestTimeout);

    testWidgets('the keypad tightens the vertical padding', (tester) async {
      await _pump(tester, _state());
      final rest = tester.getSize(_row('date')).height;

      await _pump(tester, _state(includeInAnalysis: false), keypad: true);
      final tight = tester.getSize(_row('date')).height;

      expect(rest - tight, _keypadPaddingSaving);
    }, timeout: uiTestTimeout);
  });

  group('row taps', () {
    testWidgets('each picker row requests its picker', (tester) async {
      final fixture = await _pump(
        tester,
        _state(recurrence: RecurrenceFrequency.monthly),
      );

      for (final key in ['category', 'account', 'date', 'repeat', 'ends']) {
        await tester.tap(_row(key));
      }

      expect(fixture.viewModel.calls, [
        #requestPickCategory,
        #requestPickSource,
        #requestPickDate,
        #requestPickRecurrence,
        #requestPickEnds,
      ]);
    }, timeout: uiTestTimeout);

    testWidgets('the analysis row toggles through its switch and its label', (
      tester,
    ) async {
      final fixture = await _pump(tester, _state());

      await tester.tap(find.byType(Switch));
      await tester.tap(find.text('Include in analysis'));

      expect(fixture.viewModel.calls, [
        #setIncludeInAnalysis,
        #setIncludeInAnalysis,
      ]);
    }, timeout: uiTestTimeout);
  });

  group('Add receipt', () {
    const strip = SizedBox(key: ValueKey('strip'), height: _stripHeight);
    void noop() {}

    testWidgets('is the last logical row with a camera icon and no chevron', (
      tester,
    ) async {
      await _pump(tester, _state(), onReceiptTap: noop);

      expect(
        _top(tester, 'Add receipt'),
        greaterThan(_top(tester, 'Include in analysis')),
      );
      expect(find.byType(EntryRowDivider), findsNWidgets(7));
      final row = _row('receipt');
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(Icons.camera_alt_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
        findsNothing,
      );
    }, timeout: uiTestTimeout);

    testWidgets('is absent without a tap handler', (tester) async {
      await _pump(tester, _state());

      expect(find.text('Add receipt'), findsNothing);
      expect(find.byType(EntryRowDivider), findsNWidgets(6));
    }, timeout: uiTestTimeout);

    testWidgets('a collapsed recurring hint follows the receipt row', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(recurrence: RecurrenceFrequency.monthly),
        onReceiptTap: noop,
      );

      expect(_top(tester, _hint), greaterThan(_top(tester, 'Add receipt')));
      expect(find.byType(EntryRowDivider), findsNWidgets(8));
    }, timeout: uiTestTimeout);

    testWidgets('an expanded strip sits between the receipt row and the hint', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(recurrence: RecurrenceFrequency.monthly),
        onReceiptTap: noop,
        receiptStrip: strip,
      );

      final stripTop = tester.getTopLeft(find.byKey(strip.key!)).dy;
      expect(stripTop, greaterThan(_top(tester, 'Add receipt')));
      expect(_top(tester, _hint), greaterThan(stripTop));
      expect(find.byType(EntryRowDivider), findsNWidgets(8));
    }, timeout: uiTestTimeout);

    testWidgets('tapping it unfocuses the Name field and fires once', (
      tester,
    ) async {
      var taps = 0;
      final fixture = await _pump(tester, _state(), onReceiptTap: () => taps++);
      fixture.nameFocus.requestFocus();
      await tester.pump();

      await tester.tap(find.text('Add receipt'));
      await tester.pump();

      expect(taps, 1);
      expect(fixture.nameFocus.hasFocus, isFalse);
    }, timeout: uiTestTimeout);
  });

  group('Name focus', () {
    testWidgets('tapping the Name label focuses the field once', (
      tester,
    ) async {
      final fixture = await _pump(tester, _state());

      await tester.tap(find.text('Name'));
      await tester.pump();
      expect(fixture.nameFocus.hasFocus, isTrue);

      fixture.nameController.value = const TextEditingValue(
        text: 'Lunch',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      );
      await tester.tap(find.text('Name'));
      await tester.pump();

      expect(fixture.nameFocus.hasFocus, isTrue);
      expect(fixture.nameController.text, 'Lunch');
      expect(fixture.nameController.selection.baseOffset, 1);
      expect(fixture.nameController.selection.extentOffset, 3);
    }, timeout: uiTestTimeout);

    testWidgets('a stacked Name row keeps focus when its label is tapped', (
      tester,
    ) async {
      final fixture = await _pump(
        tester,
        _state(),
        width: _stackedWidth,
        textScale: _largeText,
      );
      final name = find.byKey(const ValueKey('new-entry-name'));
      expect(
        tester.getTopLeft(name).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('Name')).dy),
      );

      await tester.tap(find.text('Name'));
      await tester.pump();
      await tester.tap(find.text('Name'));
      await tester.pump();
      await tester.tap(name);
      await tester.pump();

      expect(fixture.nameFocus.hasFocus, isTrue);
    }, timeout: uiTestTimeout);

    testWidgets('a tap outside the Name row unfocuses it', (tester) async {
      final fixture = await _pump(tester, _state());
      await tester.tap(find.text('Name'));
      await tester.pump();

      await tester.tap(_row('date'));
      await tester.pump();

      expect(fixture.nameFocus.hasFocus, isFalse);
    }, timeout: uiTestTimeout);

    testWidgets('a focused Name swaps its divider for one focus underline', (
      tester,
    ) async {
      final fixture = await _pump(tester, _state());
      final dividers = find.byType(EntryRowDivider).evaluate().length;

      await tester.tap(find.text('Name'));
      await tester.pump();
      expect(fixture.nameFocus.hasFocus, isTrue);

      expect(find.byType(EntryRowDivider), findsNWidgets(dividers - 1));
      final underline = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color == SpendWiseColors.light.focus &&
            widget.constraints?.maxHeight == _focusUnderline,
      );
      expect(underline, findsOneWidget);
    }, timeout: uiTestTimeout);
  });

  group('Note focus', () {
    testWidgets('tapping the Note label focuses once and keeps its text', (
      tester,
    ) async {
      final fixture = await _pump(tester, _state());

      await tester.tap(find.text('Note'));
      await tester.pump();
      expect(fixture.noteFocus.hasFocus, isTrue);

      fixture.noteController.value = const TextEditingValue(
        text: 'Split\nbill',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      );
      await tester.tap(find.text('Note'));
      await tester.pump();

      expect(fixture.noteFocus.hasFocus, isTrue);
      expect(fixture.noteController.text, 'Split\nbill');
      expect(fixture.noteController.selection.baseOffset, 1);
      expect(fixture.noteController.selection.extentOffset, 3);
    }, timeout: uiTestTimeout);

    testWidgets('a stacked Note row keeps focus when its label is tapped', (
      tester,
    ) async {
      final fixture = await _pump(
        tester,
        _state(),
        width: _stackedWidth,
        textScale: _largeText,
      );
      final note = find.byKey(const ValueKey('new-entry-note'));
      await tester.ensureVisible(find.text('Note'));
      await tester.pump();

      await tester.tap(find.text('Note'));
      await tester.pump();
      await tester.tap(find.text('Note'));
      await tester.pump();
      await tester.tap(note);
      await tester.pump();

      expect(fixture.noteFocus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    }, timeout: uiTestTimeout);

    testWidgets('a tap on another row unfocuses Note', (tester) async {
      final fixture = await _pump(tester, _state());
      await tester.tap(find.text('Note'));
      await tester.pump();

      await tester.tap(_row('date'));
      await tester.pump();

      expect(fixture.noteFocus.hasFocus, isFalse);
    }, timeout: uiTestTimeout);

    testWidgets('a focused Note swaps its divider for one focus underline', (
      tester,
    ) async {
      final fixture = await _pump(tester, _state());
      final dividers = find.byType(EntryRowDivider).evaluate().length;

      await tester.tap(find.text('Note'));
      await tester.pump();
      expect(fixture.noteFocus.hasFocus, isTrue);

      expect(find.byType(EntryRowDivider), findsNWidgets(dividers - 1));
      final underline = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color == SpendWiseColors.light.focus &&
            widget.constraints?.maxHeight == _focusUnderline,
      );
      expect(underline, findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('a long multiline Note grows the row without overflow', (
      tester,
    ) async {
      final fixture = await _pump(
        tester,
        _state(),
        width: _narrowWidth,
        textScale: _largeText,
      );
      final before = tester.getSize(_row('note')).height;

      fixture.noteController.text = List.filled(
        8,
        'Dinner with the team',
      ).join('\n');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(_row('note')).height, greaterThan(before));
    }, timeout: uiTestTimeout);
  });

  group('at 202 dp and 1.5x text', () {
    testWidgets('long values stack under their labels without overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(recurrence: RecurrenceFrequency.quarterly, hasEndDate: true),
        display: _longDisplay,
        width: _narrowWidth,
        textScale: _largeText,
      );

      expect(tester.takeException(), isNull);
      final label = tester.getRect(find.text('Account'));
      final value = tester.getRect(find.text(_longValue).at(1));
      expect(value.top, greaterThanOrEqualTo(label.bottom));
      expect(value.right, lessThanOrEqualTo(_narrowWidth));
      for (final text in ['Every three months', 'Include in analysis']) {
        expect(find.text(text), findsOneWidget);
      }
    }, timeout: uiTestTimeout);

    testWidgets('the receipt label and icon fit the content width', (
      tester,
    ) async {
      await _pump(
        tester,
        _state(),
        width: _narrowWidth,
        textScale: _largeText,
        onReceiptTap: () {},
      );

      expect(tester.takeException(), isNull);
      final label = tester.getRect(find.text('Add receipt'));
      expect(label.right, lessThanOrEqualTo(_narrowWidth));
      await tester.ensureVisible(_row('receipt'));
      expect(_row('receipt').hitTestable(), findsOneWidget);
    }, timeout: uiTestTimeout);

    testWidgets('the analysis label and switch fit the content width', (
      tester,
    ) async {
      await _pump(tester, _state(), width: _narrowWidth, textScale: _largeText);

      expect(tester.takeException(), isNull);
      final label = tester.getRect(find.text('Include in analysis'));
      expect(label.right, lessThanOrEqualTo(_narrowWidth));
      expect(find.byType(Switch).hitTestable(), findsOneWidget);
    }, timeout: uiTestTimeout);
  });
}
