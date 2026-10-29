import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/accounts/account_sheet_presentation.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const sheetCompletionTimeout = Duration(seconds: 5);

const sheetDraftKey = ValueKey('sheet-draft');

void useShellWindow(
  WidgetTester tester,
  Size size, {
  FakeViewPadding padding = FakeViewPadding.zero,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  addTearDown(tester.view.reset);
}

Future<void> pumpShellApp(
  WidgetTester tester,
  ProviderContainer container, {
  required Map<ShellDestination, WidgetBuilder> bodies,
  String? Function()? moneySourceId,
}) async {
  final shell = AppShell(bodies: bodies, moneySourceId: moneySourceId);
  final app = MaterialApp(builder: buildShellAppContent, home: shell);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
}

Widget _defaultSheetBuilder(BuildContext context) => const AppSheet(
  header: Text('Draft'),
  body: TextField(key: sheetDraftKey),
);

AppSheetRoute<void> pushShellSheet(
  BuildContext context, {
  WidgetBuilder builder = _defaultSheetBuilder,
}) {
  final route = AppSheetRoute<void>(
    presentation: accountSheetPresentation(context),
    presentationResolver: accountSheetPresentation,
    builder: builder,
  );
  Navigator.of(context, rootNavigator: true).push(route);
  return route;
}

Future<void> closeShellSheet(
  WidgetTester tester,
  AppSheetRoute<dynamic> route,
) async {
  route.navigator!.pop();
  await tester.pumpAndSettle();
  await route.completed.timeout(sheetCompletionTimeout);
}
