import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/layout/open_split_layout.dart';
import 'package:spendwise/ui/plans/plan_list/plans_list_view.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import '../plans_shell_test_support.dart';

const _openWindow = Size(960, 720);

typedef _Case = ({bool wide, bool sheet, bool selection, bool expected});

const _cases = <_Case>[
  (wide: true, sheet: false, selection: false, expected: true),
  (wide: true, sheet: false, selection: true, expected: false),
  (wide: true, sheet: true, selection: false, expected: false),
  (wide: true, sheet: true, selection: true, expected: false),
  (wide: false, sheet: false, selection: false, expected: false),
  (wide: false, sheet: false, selection: true, expected: false),
  (wide: false, sheet: true, selection: false, expected: false),
  (wide: false, sheet: true, selection: true, expected: false),
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

  for (final brightness in Brightness.values) {
    testWidgets('money-plans lays the list beside a reserved column at 960x720 '
        '(${brightness.name})', (tester) async {
      await pumpPlansShell(
        tester,
        mode: ShellLayoutMode.open,
        ledger: buildPlansShellLedger(),
        brightness: brightness,
        size: _openWindow,
      );

      final primary = find.byKey(openSplitPrimaryKey);
      final secondary = find.byKey(openSplitSecondaryKey);
      final inPrimary = find.descendant(
        of: primary,
        matching: find.text('Rent'),
      );
      final inSecondary = find.descendant(
        of: secondary,
        matching: find.byType(Text),
      );
      final primaryLeft = tester.getTopLeft(primary).dx;
      final secondaryLeft = tester.getTopLeft(secondary).dx;

      expect(inPrimary, findsOneWidget);
      expect(inSecondary, findsNothing);
      expect(primaryLeft, lessThan(secondaryLeft));
      expect(find.byKey(shellDetailPaneKey), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    }, timeout: uiTestTimeout);
  }
}
