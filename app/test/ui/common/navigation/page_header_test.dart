import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/navigation/page_header.dart';

import '../../../support/pump_app.dart';
import '../../../support/ui_test_timeout.dart';

const _title = 'Categories';
const _homeText = 'Home page';

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
}
