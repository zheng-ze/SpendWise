import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

void main() {
  testWidgets('an app resume inside AppShell moves today into a new month', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 3, 12);
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
      ],
    );
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(todayProvider), DateTime.utc(2026, 10, 3));
    expect(container.read(effectiveMonthProvider), DateTime.utc(2026, 10));

    now = DateTime(2026, 11, 2, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(container.read(todayProvider), DateTime.utc(2026, 11, 2));
    expect(container.read(effectiveMonthProvider), DateTime.utc(2026, 11));
  });
}
