import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/shell/desktop_sidebar.dart';
import 'package:spendwise/ui/shell/shell_destinations.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

void main() {
  for (final scale in [2.0, 3.0]) {
    testWidgets(
      'large sidebar labels fit and remain tappable at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final selected = <ShellDestination>[];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildSpendWiseTheme(Brightness.light),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.centerLeft,
                    child: DesktopSidebar(
                      selected: ShellDestination.overview,
                      onDestinationSelected: selected.add,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        for (final destination in ShellDestination.values) {
          final label = find.text(destinationLabels[destination]!);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          final item = find.ancestor(of: label, matching: find.byType(InkWell));
          final labelRect = tester.getRect(label);
          final itemRect = tester.getRect(item);
          expect(labelRect.left, greaterThanOrEqualTo(itemRect.left));
          expect(labelRect.right, lessThanOrEqualTo(itemRect.right));
          expect(labelRect.top, greaterThanOrEqualTo(itemRect.top));
          expect(labelRect.bottom, lessThanOrEqualTo(itemRect.bottom));

          if (destination == ShellDestination.overview ||
              destination == ShellDestination.settings) {
            final paragraph = tester.renderObject<RenderParagraph>(label);
            final lines = paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: destinationLabels[destination]!.length,
              ),
            );
            expect(lines.length, greaterThan(1));
          }

          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(selected.last, destination);
          expect(tester.takeException(), isNull);
        }
        expect(selected, ShellDestination.values);
      },
    );
  }
}
