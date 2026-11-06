import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/plans/plan_list/plans_list_view.dart';

typedef _Case = ({bool wide, bool sheet, bool selection, bool expected});

const _cases = <_Case>[
  (wide: true, sheet: false, selection: false, expected: true),
  (wide: false, sheet: false, selection: false, expected: false),
  (wide: true, sheet: true, selection: false, expected: false),
  (wide: true, sheet: false, selection: true, expected: false),
];

void main() {
  for (final c in _cases) {
    test('plansWideComposition wide=${c.wide} sheet=${c.sheet} '
        'selection=${c.selection} is ${c.expected}', () {
      final result = plansWideComposition(
        wideLayout: c.wide,
        sheetPresented: c.sheet,
        selectionPresent: c.selection,
      );

      expect(result, c.expected);
    });
  }
}
