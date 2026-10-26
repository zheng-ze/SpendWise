import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

void main() {
  testWidgets('closing an open detail pane runs its close action', (
    tester,
  ) async {
    var closed = false;
    await _pumpOpenShell(
      tester,
      detail: ShellDetail(
        id: 'account',
        title: 'Account details',
        bodyBuilder: (_) => const Text('Account content'),
        onClose: () => closed = true,
      ),
    );

    expect(find.text('Account content'), findsOneWidget);
    await tester.tap(find.byKey(shellDetailCloseKey));

    expect(closed, isTrue);
  });
}

Future<void> _pumpOpenShell(
  WidgetTester tester, {
  required ShellDetail detail,
}) async {
  final container = ProviderContainer(
    overrides: [
      shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: _shellHome(detail)),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _shellHome(ShellDetail detail) => AppShell(
  bodies: {
    ShellDestination.overview: (_) => ShellPaneHost(
      detail: detail,
      pageBuilder: (_, _) => const SizedBox.shrink(),
    ),
  },
);
