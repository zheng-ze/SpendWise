import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/desktop_sidebar.dart';
import 'package:spendwise/ui/shell/open_rail.dart';
import 'package:spendwise/ui/shell/phone_bar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../../support/ui_test_timeout.dart';
import 'new_entry_session_harness.dart';

const _desktopSize = Size(1280, 800);

Future<void> _tapNavigationDestination(
  WidgetTester tester,
  Finder navigation,
) async {
  await tester.tap(
    find.descendant(of: navigation.last, matching: find.text('History')),
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone Add covers the shell tab bar without a second copy', (
    tester,
  ) async {
    final harness = await pumpShell(tester);
    await openAdd(tester, harness);

    expect(find.byType(PhoneBar), findsOneWidget);
    await _tapNavigationDestination(tester, find.byType(PhoneBar));

    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
  }, timeout: uiTestTimeout);

  testWidgets('open rail tap selects destination and dismisses Add', (
    tester,
  ) async {
    final harness = await pumpShell(tester, size: openSize);
    await openAdd(tester, harness);

    await _tapNavigationDestination(tester, find.byKey(openRailKey));

    expect(find.byType(AppSheet), findsNothing);
    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
  }, timeout: uiTestTimeout);

  testWidgets('desktop sidebar stays mounted and acts as an outside tap', (
    tester,
  ) async {
    final harness = await pumpShell(
      tester,
      size: _desktopSize,
      platform: TargetPlatform.macOS,
    );
    await openAdd(tester, harness);

    expect(find.byType(DesktopSidebar), findsOneWidget);
    await _tapNavigationDestination(tester, find.byType(DesktopSidebar));

    expect(find.byType(AppSheet), findsNothing);
    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
  }, timeout: uiTestTimeout);

  testWidgets('desktop sidebar surface dismisses only Add', (tester) async {
    final harness = await pumpShell(
      tester,
      size: _desktopSize,
      platform: TargetPlatform.macOS,
    );
    await openAdd(tester, harness);

    await tester.tapAt(const Offset(4, 500));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsNothing);
    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
  }, timeout: uiTestTimeout);

  testWidgets('outside tap dismisses Add without changing destination', (
    tester,
  ) async {
    final harness = await pumpShell(tester, size: openSize);
    await openAdd(tester, harness);

    await tester.tapAt(const Offset(120, 120));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheet), findsNothing);
    expect(
      harness.container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
  }, timeout: uiTestTimeout);
}
