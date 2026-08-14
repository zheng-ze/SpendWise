import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/status_banner.dart';

const _warning = 'This browser will not keep your data after you close the tab';

Future<void> _pumpShell(WidgetTester tester, {required bool durable}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [storageIsDurableProvider.overrideWithValue(durable)],
      child: const MaterialApp(home: AppShell()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('durable storage shows no warning', (tester) async {
    await _pumpShell(tester, durable: true);

    expect(find.text(_warning), findsNothing);
  });

  testWidgets('storage that is not durable warns inside the shell', (
    tester,
  ) async {
    await _pumpShell(tester, durable: false);

    expect(find.text(_warning), findsOneWidget);
  });

  testWidgets('the warning is not the dismissible overlay banner', (
    tester,
  ) async {
    await _pumpShell(tester, durable: false);

    expect(
      find.descendant(
        of: find.byType(StatusBanner),
        matching: find.text(_warning),
      ),
      findsNothing,
    );
  });

  testWidgets('the warning survives a destination switch', (tester) async {
    await _pumpShell(tester, durable: false);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text(_warning), findsOneWidget);
  });
}
