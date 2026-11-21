import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/navigation/page_header.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _title = 'Categories';
const _homeText = 'Home page';
const _subtitle = 'Groceries';
const _trailing = 'Edit';

class _PushedHeader extends StatelessWidget {
  const _PushedHeader();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageHeader(title: _title, onBack: Navigator.of(context).maybePop),
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
  testWidgets('tapping the back control pops the route', (tester) async {
    await pumpApp(tester, const _Home());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsNothing);
    expect(find.text(_homeText), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('a disabled back stays visible and does nothing', (tester) async {
    const header = Scaffold(
      body: PageHeader(title: _title, disabledBack: true, subtitle: _subtitle),
    );
    await pumpApp(tester, header);

    final button = tester.widget<IconButton>(find.byType(IconButton));

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(button.onPressed, isNull);
    expect(find.text(_subtitle), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('the trailing action is shown and tappable', (tester) async {
    var taps = 0;
    final trailing = TextButton(
      onPressed: () => taps++,
      child: const Text(_trailing),
    );
    await pumpApp(
      tester,
      Scaffold(
        body: PageHeader(title: _title, onBack: () {}, trailing: trailing),
      ),
    );

    await tester.tap(find.text(_trailing));

    expect(taps, 1);
  }, timeout: uiTestTimeout);
}
