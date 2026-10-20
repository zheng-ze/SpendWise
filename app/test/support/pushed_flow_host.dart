import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const flowHostMarker = 'flow host';

Future<void> pumpFlowInPushedRoute(
  WidgetTester tester, {
  required ProviderContainer container,
  required Widget flow,
}) async {
  const host = MaterialApp(home: Scaffold(body: Text(flowHostMarker)));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: host),
  );
  final context = tester.element(find.text(flowHostMarker));
  final route = MaterialPageRoute<void>(builder: (_) => flow);
  unawaited(Navigator.of(context).push(route));
}
