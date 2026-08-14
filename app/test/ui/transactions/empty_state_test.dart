import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/transactions/empty_state.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the tray icon and the no-transactions message', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const TransactionsEmptyState()));

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('No transactions'), findsOneWidget);
  });
}
