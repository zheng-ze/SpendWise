import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> performCustomSemanticsAction(
  WidgetTester tester, {
  required Finder of,
  required String label,
}) async {
  final node = tester.getSemantics(of);
  final data = node.getSemanticsData();
  final actionIds = data.customSemanticsActionIds ?? const <int>[];
  final matchingId = actionIds.firstWhere(
    (id) => CustomSemanticsAction.getAction(id)?.label == label,
    orElse: () => throw TestFailure(
      'No custom semantics action labeled "$label" was found on the node '
      'for $of.',
    ),
  );

  node.owner!.performAction(node.id, SemanticsAction.customAction, matchingId);
}
