import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';

const _groups = [
  PickerOption(
    id: 'food',
    label: 'Food',
    children: [
      PickerOption(id: 'cafe', label: 'Cafe'),
      PickerOption(id: 'grocery', label: 'Grocery'),
    ],
  ),
  PickerOption(
    id: 'travel',
    label: 'Travel',
    children: [PickerOption(id: 'taxi', label: 'Taxi')],
  ),
];

Future<PickerOutcome?> _openAndAct(
  WidgetTester tester,
  Future<void> Function(WidgetTester tester) act, {
  bool allowsNone = false,
}) async {
  PickerOutcome? outcome;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              outcome = await showTwoColumnPickerSheet(
                context: context,
                title: 'Category',
                groups: _groups,
                allowsNone: allowsNone,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await act(tester);
  await tester.pumpAndSettle();

  return outcome;
}

void main() {
  testWidgets('choosing a leaf returns that id', (tester) async {
    final outcome = await _openAndAct(tester, (tester) async {
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grocery'));
    });

    expect(outcome, isA<PickerChose>());
    expect((outcome! as PickerChose).id, 'grocery');
  });

  testWidgets('dismissing returns cancelled, never a cleared selection', (
    tester,
  ) async {
    final outcome = await _openAndAct(tester, (tester) async {
      await tester.tapAt(const Offset(400, 20));
    });

    expect(outcome, isNull);
  });

  testWidgets('confirming None is distinct from cancelling', (tester) async {
    final outcome = await _openAndAct(tester, (tester) async {
      await tester.tap(find.text('None'));
    }, allowsNone: true);

    expect(outcome, isA<PickerCleared>());
  });

  testWidgets('None is absent unless the caller allows it', (tester) async {
    await _openAndAct(tester, (tester) async {
      expect(find.text('None'), findsNothing);
    });
  });

  testWidgets('the selected row exposes its selected state via semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwoColumnPickerSheet(
            title: 'Category',
            groups: _groups,
            selectedId: 'food',
          ),
        ),
      ),
    );

    final selectedNode = tester.getSemantics(find.text('Food'));
    expect(
      selectedNode.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );

    final unselectedNode = tester.getSemantics(find.text('Travel'));
    expect(
      unselectedNode.getSemanticsData().flagsCollection.isSelected,
      isNot(Tristate.isTrue),
    );

    handle.dispose();
  });
}
