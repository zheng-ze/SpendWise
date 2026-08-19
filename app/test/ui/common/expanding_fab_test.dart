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

  testWidgets('a single action exposes its label via semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(
        ExpandingFab(
          primary: FabAction(
            label: 'Add Transaction',
            icon: Icons.add,
            onTap: () {},
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(FloatingActionButton));
    expect(node.tooltip, 'Add Transaction');

    handle.dispose();
  });

  testWidgets('expanded action capsules expose their labels via semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

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

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final addNode = tester.getSemantics(find.text('Add Transaction'));
    expect(addNode.label, 'Add Transaction');
    expect(addNode.getSemanticsData().flagsCollection.isButton, isTrue);

    final editNode = tester.getSemantics(find.text('Edit Checking'));
    expect(editNode.label, 'Edit Checking');
    expect(editNode.getSemanticsData().flagsCollection.isButton, isTrue);

    handle.dispose();
  });

  testWidgets('the toggle announces its expand and collapse state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

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

    final collapsedNode = tester.getSemantics(
      find.byType(FloatingActionButton),
    );
    expect(collapsedNode.tooltip, 'Add Transaction');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final expandedNode = tester.getSemantics(find.byIcon(Icons.close));
    expect(expandedNode.tooltip, 'Close menu');

    handle.dispose();
  });
}
