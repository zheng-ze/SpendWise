import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

void main() {
  test('iOS and Android resolve to phone', () {
    expect(
      resolveShellLayoutMode(isWeb: false, targetPlatform: TargetPlatform.iOS),
      ShellLayoutMode.phone,
    );
    expect(
      resolveShellLayoutMode(
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      ShellLayoutMode.phone,
    );
  });

  test('macOS, Windows and Linux resolve to desktop', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        resolveShellLayoutMode(isWeb: false, targetPlatform: platform),
        ShellLayoutMode.desktop,
      );
    }
  });

  test('an unsupported platform falls back to desktop', () {
    expect(
      resolveShellLayoutMode(
        isWeb: false,
        targetPlatform: TargetPlatform.fuchsia,
      ),
      ShellLayoutMode.desktop,
    );
  });

  test('web resolves to desktop regardless of target platform', () {
    for (final platform in TargetPlatform.values) {
      expect(
        resolveShellLayoutMode(isWeb: true, targetPlatform: platform),
        ShellLayoutMode.desktop,
      );
    }
  });

  testWidgets('a provider override selects the bar on a desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
          shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.phone),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a provider override selects the rail on a phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
          shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.desktop),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  test('the mode persists for the container lifetime', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(shellLayoutModeProvider), ShellLayoutMode.phone);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(container.read(shellLayoutModeProvider), ShellLayoutMode.phone);
  });
}
