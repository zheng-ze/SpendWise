import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/common/feedback/delete_confirmation.dart';
import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_purge_dialog.dart';
import 'package:spendwise/ui/settings/recycle_bin/recycle_bin_view_model.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_confirmation.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/shell_pane_host.dart';

import '../../support/ui_test_timeout.dart';

const _openSize = Size(960, 720);
const _phoneSize = Size(400, 800);

class _ProbeFlow extends FlowBase<String> {
  const _ProbeFlow({required this.label});

  final String label;

  @override
  ConsumerState<_ProbeFlow> createState() => _ProbeFlowState();
}

class _ProbeFlowState extends FlowBaseState<String, _ProbeFlow> {
  @override
  void Function() subscribeToStep(void Function(String? step) handle) => () {};

  @override
  void handleStep(BuildContext context, String step) {}

  @override
  Widget buildRoot(BuildContext context) => Text(widget.label);
}

Map<ShellDestination, WidgetBuilder> _probeBodies() => {
  ShellDestination.overview: (context) =>
      const _ProbeFlow(label: 'overview probe'),
  ShellDestination.history: (context) =>
      const _ProbeFlow(label: 'history probe'),
  ShellDestination.money: (context) => const _ProbeFlow(label: 'money probe'),
  ShellDestination.settings: (context) =>
      const _ProbeFlow(label: 'settings probe'),
};

Future<ProviderContainer> _pumpBoundShell(
  WidgetTester tester, {
  required Size size,
  Map<ShellDestination, WidgetBuilder>? bodies,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
      shellPlatformProvider.overrideWith(
        (ref) => (isWeb: false, targetPlatform: TargetPlatform.iOS),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: buildShellAppContent,
        navigatorObservers: [AppSheetRouteObserver()],
        home: AppShell(bodies: bodies ?? _probeBodies()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Widget _confirmationDetail(BuildContext context) => const Text('detail probe');

Future<bool?> _openTestDialog(BuildContext context) {
  return showShellConfirmation<bool>(
    context,
    builder: (_) => const Dialog(
      child: SizedBox(width: 200, height: 100, child: Text('confirm body')),
    ),
  );
}

void main() {
  testWidgets('the dialog lives on the root navigator from any pane', (
    tester,
  ) async {
    final container = await _pumpBoundShell(tester, size: _openSize);
    final overviewContext = tester.element(find.text('overview probe'));
    final nested = Navigator.of(overviewContext);
    final root = Navigator.of(overviewContext, rootNavigator: true);
    expect(nested, isNot(root));

    var future = _openTestDialog(overviewContext);
    await tester.pumpAndSettle();
    expect(Navigator.of(tester.element(find.text('confirm body'))), root);
    root.pop(false);
    await tester.pumpAndSettle();
    expect(await future, isFalse);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    await tester.pumpAndSettle();
    final moneyContext = tester.element(find.text('money probe'));
    future = _openTestDialog(moneyContext);
    await tester.pumpAndSettle();
    Navigator.of(moneyContext, rootNavigator: true).pop(true);
    await tester.pumpAndSettle();
    expect(await future, isTrue);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.overview;
    await tester.pumpAndSettle();
    final activeOverviewContext = tester.element(find.text('overview probe'));
    final overviewNavigator = Navigator.of(activeOverviewContext);
    BuildContext? detailContext;
    final detailRoute = overviewNavigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Builder(
          builder: (context) {
            detailContext = context;
            return const Scaffold(body: Text('synthetic detail probe'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final detailFuture = _openTestDialog(detailContext!);
    await tester.pumpAndSettle();
    expect(Navigator.of(tester.element(find.text('confirm body'))), root);
    root.pop(false);
    await tester.pumpAndSettle();
    expect(await detailFuture, isFalse);
    await overviewNavigator.maybePop();
    await tester.pumpAndSettle();
    await detailRoute;
  }, timeout: uiTestTimeout);

  testWidgets('Add route confirmation retains its draft through resize', (
    tester,
  ) async {
    final bodies = _probeBodies();
    bodies[ShellDestination.overview] = (_) => ShellPaneHost(
      detail: const ShellDetail(
        id: 'confirmation-detail',
        title: 'Detail',
        bodyBuilder: _confirmationDetail,
      ),
      pageBuilder: (_, _) => const _ProbeFlow(label: 'overview probe'),
    );
    final container = await _pumpBoundShell(
      tester,
      size: _openSize,
      bodies: bodies,
    );
    final pageContext = tester.element(find.text('overview probe'));
    Future<bool?>? confirmation;
    var draft = '';
    final addRoute = showAppSheet<void>(
      pageContext,
      presentation: AppSheetPresentation.open,
      presentationResolver: (context) =>
          switch (ShellLayoutModeScope.maybeOf(context)) {
            ShellLayoutMode.open => AppSheetPresentation.open,
            ShellLayoutMode.desktop => AppSheetPresentation.desktop,
            _ => AppSheetPresentation.phone,
          },
      builder: (routeContext) => StatefulBuilder(
        builder: (context, setState) => Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add draft probe'),
              TextField(
                key: const ValueKey('add-draft-field'),
                onChanged: (value) => setState(() => draft = value),
              ),
              Text(draft),
              TextButton(
                onPressed: () {
                  confirmation = showShellConfirmation<bool>(
                    routeContext,
                    builder: (dialogContext) => Dialog(
                      child: SizedBox(
                        width: 200,
                        height: 100,
                        child: Column(
                          children: [
                            const Text('Add confirmation probe'),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Confirm from Add'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('add-draft-field')),
      'draft',
    );
    await tester.tap(find.text('Confirm from Add'));
    await tester.pumpAndSettle();
    final pendingConfirmation = confirmation!;
    expect(find.text('Add confirmation probe'), findsOneWidget);

    tester.view.physicalSize = _phoneSize;
    await tester.pumpAndSettle();

    expect(identical(confirmation, pendingConfirmation), isTrue);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'draft',
    );
    expect(find.text('Add confirmation probe'), findsOneWidget);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await pendingConfirmation, isFalse);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'draft',
    );

    Navigator.of(pageContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();
    await addRoute;
  }, timeout: uiTestTimeout);

  testWidgets('resize keeps the dialog, future and destination', (
    tester,
  ) async {
    final container = await _pumpBoundShell(tester, size: _openSize);
    final context = tester.element(find.text('overview probe'));

    var completed = false;
    bool? result;
    final future = _openTestDialog(context).then((value) {
      completed = true;
      result = value;
      return value;
    });
    await tester.pumpAndSettle();
    expect(find.text('confirm body'), findsOneWidget);

    tester.view.physicalSize = _phoneSize;
    await tester.pumpAndSettle();
    expect(find.text('confirm body'), findsOneWidget);
    expect(completed, isFalse);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );

    tester.view.physicalSize = _openSize;
    await tester.pumpAndSettle();

    Navigator.of(context, rootNavigator: true).pop(true);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isTrue);
    expect(await future, isTrue);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
  }, timeout: uiTestTimeout);

  testWidgets('cancel dismisses with false and no mutation', (tester) async {
    await _pumpBoundShell(tester, size: _openSize);
    final context = tester.element(find.text('overview probe'));

    var mutated = false;
    final future = showDeleteConfirmation(context, itemName: 'Groceries').then((
      confirmed,
    ) {
      if (confirmed) mutated = true;
      return confirmed;
    });
    await tester.pumpAndSettle();
    expect(find.text('Delete Groceries?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await future, isFalse);
    expect(mutated, isFalse);
    expect(find.text('Delete Groceries?'), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('barrier dismissal cancels with no mutation', (tester) async {
    await _pumpBoundShell(tester, size: _openSize);
    final context = tester.element(find.text('overview probe'));

    var mutated = false;
    final future = showDeleteConfirmation(context, itemName: 'Groceries').then((
      confirmed,
    ) {
      if (confirmed) mutated = true;
      return confirmed;
    });
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(100, 360));
    await tester.pumpAndSettle();

    expect(await future, isFalse);
    expect(mutated, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('back cancels with no mutation', (tester) async {
    await _pumpBoundShell(tester, size: _openSize);
    final context = tester.element(find.text('overview probe'));

    var mutated = false;
    final future = showDeleteConfirmation(context, itemName: 'Groceries').then((
      confirmed,
    ) {
      if (confirmed) mutated = true;
      return confirmed;
    });
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(await future, isFalse);
    expect(mutated, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('a rail tap behind the dim layer is inert', (tester) async {
    final container = await _pumpBoundShell(tester, size: _openSize);
    final context = tester.element(find.text('overview probe'));

    final future = showDeleteConfirmation(context, itemName: 'Groceries');
    await tester.pumpAndSettle();
    final railPoint = tester.getCenter(find.text('History'));
    final dialogPoint = tester.getCenter(find.text('Delete Groceries?'));

    await tester.tapAt(dialogPoint);
    await tester.pumpAndSettle();
    expect(find.text('Delete Groceries?'), findsOneWidget);
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );

    await tester.tapAt(railPoint);
    await tester.pumpAndSettle();
    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.overview,
    );
    expect(await future, isFalse);
  }, timeout: uiTestTimeout);

  testWidgets('purge keeps its wording and maps dismissal to false', (
    tester,
  ) async {
    await _pumpBoundShell(tester, size: _openSize);
    final context = tester.element(find.text('overview probe'));
    const row = BinRow(
      kind: BinRowKind.account,
      id: 'account-id',
      name: 'Holiday fund',
    );

    final future = confirmBinPurge(context, row);
    await tester.pumpAndSettle();

    expect(find.text('Delete permanently?'), findsOneWidget);
    expect(
      find.textContaining('Holiday fund leaves the bin for good'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await future, isFalse);

    final confirmed = confirmBinPurge(context, row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await confirmed, isTrue);
  }, timeout: uiTestTimeout);

  testWidgets('focus traversal stays inside the dialog', (tester) async {
    await _pumpBoundShell(tester, size: _openSize);
    final context = tester.element(find.text('overview probe'));

    final future = showDeleteConfirmation(context, itemName: 'Groceries');
    await tester.pumpAndSettle();

    for (var step = 0; step < 6; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(focused.findAncestorWidgetOfExactType<Dialog>(), isNotNull);
    }

    Navigator.of(context, rootNavigator: true).pop(false);
    await tester.pumpAndSettle();
    expect(await future, isFalse);
  }, timeout: uiTestTimeout);
}
