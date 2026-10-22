import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../support/ui_test_timeout.dart';

const _openSize = Size(960, 720);
const _detailTitle = 'Detail title';
const _headerActionLabel = 'Header action';
const _closeLabel = 'Close';

Widget _pageBody(BuildContext context, ShellPagePresentation presentation) =>
    const SizedBox.expand();

Widget _detailBody(BuildContext context) => const SizedBox.expand();

Future<void> _pumpDetail(WidgetTester tester, {VoidCallback? onClose}) async {
  tester.view.physicalSize = _openSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final detail = ShellDetail(
    id: 'detail',
    title: _detailTitle,
    bodyBuilder: _detailBody,
    onClose: onClose,
    headerActions: const [Text(_headerActionLabel)],
  );
  final host = ShellPaneHost(pageBuilder: _pageBody, detail: detail);
  final scope = ShellPaneScope(
    mode: ShellLayoutMode.open,
    safeBodyWidth: _openSize.width,
    addPresented: false,
    child: host,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSpendWiseTheme(Brightness.light),
      home: Scaffold(body: scope),
    ),
  );
}

void main() {
  testWidgets('a detail without onClose omits Close and keeps its header', (
    tester,
  ) async {
    await _pumpDetail(tester);

    expect(find.byKey(shellDetailCloseKey), findsNothing);
    expect(find.text(_detailTitle), findsOneWidget);
    expect(find.text(_headerActionLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('a detail with onClose shows a Close that calls it', (
    tester,
  ) async {
    var closeCount = 0;
    await _pumpDetail(tester, onClose: () => closeCount++);

    expect(find.text(_closeLabel), findsOneWidget);
    await tester.tap(find.byKey(shellDetailCloseKey));
    await tester.pump();

    expect(closeCount, 1);
  }, timeout: uiTestTimeout);
}
