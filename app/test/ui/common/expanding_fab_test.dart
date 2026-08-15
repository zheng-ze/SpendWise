import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/expanding_fab.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Stack(children: [child])),
  );

  testWidgets('a single action fires directly with no expansion', (
    tester,
  ) async {
    var fired = false;
    await tester.pumpWidget(
      wrap(
        ExpandingFab(
          primary: FabAction(
            label: 'Add Transaction',
            icon: Icons.add,
            onTap: () => fired = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(fired, isTrue);
    expect(find.text('Add Transaction'), findsNothing);
  });

  testWidgets('two actions expand into labelled capsules on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ExpandingFab(
          primary: FabAction(
            label: 'Add Transaction',
            icon: Icons.add,
            onTap: () {},
          ),
          secondary: FabAction(
            label: 'Edit Checking',
            icon: Icons.edit,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Add Transaction'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Add Transaction'), findsOneWidget);
    expect(find.text('Edit Checking'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('choosing an action collapses first, then fires', (tester) async {
    var fired = false;
    await tester.pumpWidget(
      wrap(
        ExpandingFab(
          primary: FabAction(
            label: 'Add Transaction',
            icon: Icons.add,
            onTap: () => fired = true,
          ),
          secondary: FabAction(
            label: 'Edit Checking',
            icon: Icons.edit,
            onTap: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Transaction'));
    await tester.pumpAndSettle();

    expect(fired, isTrue);
    expect(find.text('Add Transaction'), findsNothing);
    expect(find.text('Edit Checking'), findsNothing);
  });

  testWidgets('tapping the backdrop collapses without firing either action', (
    tester,
  ) async {
    var primaryFired = false;
    var secondaryFired = false;
    await tester.pumpWidget(
      wrap(
        ExpandingFab(
          primary: FabAction(
            label: 'Add Transaction',
            icon: Icons.add,
            onTap: () => primaryFired = true,
          ),
          secondary: FabAction(
            label: 'Edit Checking',
            icon: Icons.edit,
            onTap: () => secondaryFired = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add Transaction'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Add Transaction'), findsNothing);
    expect(primaryFired, isFalse);
    expect(secondaryFired, isFalse);
  });
}
