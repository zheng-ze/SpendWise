import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/settings/symbol_picker.dart';

void main() {
  group('filterSymbolSections', () {
    const sections = {
      'Food & Drink': ['restaurant', 'local_cafe'],
      'Transport': ['directions_car', 'flight'],
      'Money': ['savings', 'attach_money'],
    };

    test('empty query returns every section unchanged', () {
      expect(filterSymbolSections(sections, ''), sections);
    });

    test('a term matching only some sections drops the rest entirely', () {
      final result = filterSymbolSections(sections, 'car');
      expect(result.keys, ['Transport']);
      expect(result['Transport'], ['directions_car']);
    });

    test('matching is case-insensitive and trims the query', () {
      final result = filterSymbolSections(sections, '  CAFE  ');
      expect(result.keys, ['Food & Drink']);
      expect(result['Food & Drink'], ['local_cafe']);
    });

    test('a query matching nothing returns no sections', () {
      expect(filterSymbolSections(sections, 'zzz'), isEmpty);
    });
  });

  testWidgets('tapping a symbol pops with its name', (tester) async {
    String? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await showSymbolPickerSheet(
                context: context,
                selected: 'tag',
                color: Colors.blue,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Icon'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.restaurant));
    await tester.pumpAndSettle();

    expect(popped, 'restaurant');
  });

  testWidgets('cancelling returns null', (tester) async {
    String? popped = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await showSymbolPickerSheet(
                context: context,
                selected: 'tag',
                color: Colors.blue,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(popped, isNull);
  });
}
