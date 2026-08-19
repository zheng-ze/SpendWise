import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/error_section.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester, LedgerError? error) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorSection(subject: 'entry', error: error),
        ),
      ),
    );
  }

  testWidgets('shows a plain-language message, not the raw toString, for '
      'InactiveReference', (tester) async {
    await pumpSection(
      tester,
      const InactiveReference('a0000000-0000-0000-0000-000000000001'),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, isNot(contains('LedgerError.')));
    expect(text.data, isNotNull);
    expect(text.data!.trim(), isNotEmpty);
  });

  testWidgets('shows a plain-language message, not the raw toString, for '
      'CategoryKindMismatch', (tester) async {
    await pumpSection(tester, const CategoryKindMismatch());

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, isNot(contains('LedgerError.')));
    expect(text.data, isNotNull);
    expect(text.data!.trim(), isNotEmpty);
  });
}
