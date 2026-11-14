import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/navigation/page_header.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _title = 'Categories';
const _backLabel = 'Settings';
const _homeText = 'Home page';

class _PushedHeader extends StatelessWidget {
  const _PushedHeader();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageHeader(
      title: _title,
      backLabel: _backLabel,
      onBack: Navigator.of(context).maybePop,
    ),
  );
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final route = MaterialPageRoute<void>(
      builder: (_) => const _PushedHeader(),
    );
    return Scaffold(
      body: Column(
        children: [
          const Text(_homeText),
          TextButton(
            onPressed: () => Navigator.of(context).push(route),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('the header shows the title and the back label', (tester) async {
    await pumpApp(tester, const Scaffold(body: PageHeader(title: _title)));

    expect(find.text(_title), findsOneWidget);
    expect(find.text(_backLabel), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('tapping the labelled back control pops the route', (
    tester,
  ) async {
    await pumpApp(tester, const _Home());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);

    await tester.tap(find.text(_backLabel));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsNothing);
    expect(find.text(_homeText), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('the back control exposes the label to accessibility', (
    tester,
  ) async {
    await pumpApp(tester, const _PushedHeader());

    expect(find.bySemanticsLabel(_backLabel), findsOneWidget);
  }, timeout: uiTestTimeout);
}
