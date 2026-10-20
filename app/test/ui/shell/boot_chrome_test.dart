import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/add_sheet_dismiss.dart';

import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/persistence/store/ledger_store.dart';
import 'package:spendwise/ui/overview/overview_screen.dart';
import 'package:spendwise/ui/overview/overview_flow.dart';
import 'package:spendwise/ui/overview/overview_view_model.dart';
import 'package:spendwise/ui/accounts/accounts_view_model.dart';
import 'package:spendwise/ui/accounts/accounts_flow.dart';
import 'package:spendwise/ui/money/money_flow.dart';
import 'package:spendwise/boot/money_navigation_provider.dart';
import 'package:spendwise/ui/transactions/entry/entry_form_view_model.dart';
import 'package:spendwise/ui/transactions/transactions_flow.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/boot_chrome.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/desktop_sidebar.dart';
import 'package:spendwise/ui/shell/phone_bar.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/shell/spendwise_wordmark.dart';
import 'package:spendwise/ui/settings/settings_flow.dart';
// Temporary exclusion: this MUST be resolved when the new Trends screen is ready.
// import 'package:spendwise/ui/stats/stats_root_screen.dart';
import 'package:spendwise/ui/theme/spendwise_colors.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../support/in_memory_ledger_store.dart';
import '../../support/ui_test_timeout.dart';

class _GatedStoreFactory {
  _GatedStoreFactory();

  Completer<LedgerStore>? _pending;

  int startCount = 0;

  Future<LedgerStore> call() {
    startCount++;
    final gate = Completer<LedgerStore>();
    _pending = gate;
    return gate.future;
  }

  void fail(Object error) => _pending!.completeError(error);

  void succeed() => _pending!.complete(InMemoryLedgerStore());
}

void main() {
  Widget hostedIn(
    ProviderContainer container, {
    Brightness brightness = Brightness.light,
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: buildSpendWiseTheme(brightness),
      home: const BootChrome(),
    ),
  );

  Widget hostedBoundIn(
    WidgetTester tester,
    ProviderContainer container,
    Size size,
  ) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: buildShellAppContent,
        home: const BootChrome(),
      ),
    );
  }

  ShellLayoutMode boundMode(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(BootChrome)))
          .read(shellLayoutModeProvider);

  void expectWordmark(WidgetTester tester, Color actionColor) {
    final wordmark = find.byType(SpendWiseWordmark);
    expect(wordmark, findsOneWidget);
    final text = tester.widget<Text>(
      find.descendant(of: wordmark, matching: find.byType(Text)),
    );
    final span = text.textSpan as TextSpan;
    expect(span.toPlainText(), 'SpendWise');
    final wise = span.children?.last as TextSpan;
    expect(wise.style?.color, actionColor);
  }

  void expectNoShellNavigation() {
    expect(find.byType(AppShell), findsNothing);
    expect(find.byType(PhoneBar), findsNothing);
    expect(find.byType(DesktopSidebar), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(OverviewFlow), findsNothing);
    expect(find.byType(TransactionsFlow), findsNothing);
    // Temporary exclusion: this MUST be resolved when the new Trends screen is ready.
    // expect(find.byType(StatsRootScreen), findsNothing);
    expect(find.byType(AccountsFlow), findsNothing);
    expect(find.byType(SettingsFlow), findsNothing);
  }

  ProviderContainer containerWith(_GatedStoreFactory factory) {
    final container = ProviderContainer(
      overrides: [
        appBootProvider.overrideWith(
          (ref) =>
              AppBoot(createStore: factory.call, seedChanges: seedChanges)
                ..start(),
        ),
        analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('loading uses the theme background and accessible wordmark', (
    tester,
  ) async {
    final factory = _GatedStoreFactory();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      hostedIn(containerWith(factory), brightness: Brightness.dark),
    );

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      SpendWiseColors.dark.base,
    );
    expectWordmark(tester, SpendWiseColors.dark.action);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Loading your data'), findsOneWidget);
    expectNoShellNavigation();

    factory.fail(StateError('loading diagnostic sentinel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();

    expect(find.textContaining('loading diagnostic sentinel'), findsNothing);
    expect(find.bySemanticsLabel('Loading your data'), findsOneWidget);
    expectNoShellNavigation();
    semantics.dispose();
  }, timeout: uiTestTimeout);

  testWidgets('failure shows exact copy, wordmark and filled retry', (
    tester,
  ) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.fail(StateError('disk on fire'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      SpendWiseColors.light.base,
    );
    expectWordmark(tester, SpendWiseColors.light.action);
    expect(find.text("Couldn't load your data"), findsOneWidget);
    expect(
      find.text('Something went wrong loading your data. Please try again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expectNoShellNavigation();
  }, timeout: uiTestTimeout);

  testWidgets('failure does not leak the raw exception text to the user', (
    tester,
  ) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.fail(Exception('DriftException: disk image is malformed'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('DriftException: disk image is malformed'),
      findsNothing,
    );
    expect(
      find.textContaining("Something went wrong loading your data"),
      findsOneWidget,
    );
    expectNoShellNavigation();
  }, timeout: uiTestTimeout);

  testWidgets('retry re-enters loading and re-runs boot', (tester) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.fail(StateError('disk on fire'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("Couldn't load your data"), findsNothing);
    expect(find.textContaining('disk on fire'), findsNothing);
    expectWordmark(tester, SpendWiseColors.light.action);
    expectNoShellNavigation();
    expect(factory.startCount, 2);
  }, timeout: uiTestTimeout);

  testWidgets('failure retry remains reachable on a short window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.fail(StateError('disk on fire'));
    await tester.pumpAndSettle();

    final retry = find.widgetWithText(FilledButton, 'Retry');
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pump();

    expect(factory.startCount, 2);
  }, timeout: uiTestTimeout);

  testWidgets('loading content does not overflow a short window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: uiTestTimeout);

  testWidgets('ready shows the shell', (tester) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.succeed();
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('BootChrome injects scoped Money Add source into the shell', (
    tester,
  ) async {
    final factory = _GatedStoreFactory();
    final container = containerWith(factory);
    await tester.pumpWidget(hostedIn(container));
    factory.succeed();
    await tester.pumpAndSettle();

    final accountState = await container.read(accountsViewModelProvider.future);
    final account = accountState.sections
        .expand((section) => section.rows)
        .firstWhere((row) => row.pockets.isNotEmpty);
    final pocketId = account.pockets.first.id;
    final observer = container.read(moneyNavigatorObserverProvider);
    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    await tester.pumpAndSettle();
    expect(find.byType(MoneyFlow), findsOneWidget);
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    container.read(accountsViewModelProvider.notifier).openAccount(account.id);
    await tester.pumpAndSettle();
    expect(observer.sourceId, account.id);

    Future<void> addAndExpectSource(String? expectedSourceId) async {
      final addControl = find.text('Add').evaluate().isNotEmpty
          ? find.text('Add')
          : find.text('Add entry');
      await tester.tap(addControl);
      await tester.pumpAndSettle();
      expect(
        container.read(entryFormViewModelProvider(null)).value?.sourceId,
        expectedSourceId,
      );
      await dismissAddSheet(tester);
      await tester.pumpAndSettle();
    }

    await addAndExpectSource(account.id);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.history;
    await tester.pumpAndSettle();
    expect(
      identical(container.read(moneyNavigatorObserverProvider), observer),
      isTrue,
    );
    await addAndExpectSource(null);

    container.read(selectedDestinationProvider.notifier).state =
        ShellDestination.money;
    await tester.pumpAndSettle();
    await addAndExpectSource(account.id);
    expect(observer.sourceId, account.id);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    container
        .read(accountsViewModelProvider.notifier)
        .openAccountAlone(account.id);
    await tester.pumpAndSettle();
    expect(observer.sourceId, account.id);
    await addAndExpectSource(account.id);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    container.read(accountsViewModelProvider.notifier).openPocket(pocketId);
    await tester.pumpAndSettle();
    expect(observer.sourceId, pocketId);
    await addAndExpectSource(pocketId);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(observer.sourceId, isNull);
    await addAndExpectSource(null);
  }, timeout: uiTestTimeout);

  testWidgets('ready shows real content in the overview tab, not an '
      'empty placeholder', (tester) async {
    final factory = _GatedStoreFactory();
    await tester.pumpWidget(hostedIn(containerWith(factory)));

    factory.succeed();
    await tester.pumpAndSettle();

    expect(find.byType(OverviewScreen), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('an open overview history request selects shell history '
      'without pushing a route', (tester) async {
    final factory = _GatedStoreFactory();
    final container = containerWith(factory);
    await tester.pumpWidget(
      hostedBoundIn(tester, container, const Size(960, 720)),
    );
    factory.succeed();
    await tester.pumpAndSettle();
    expect(boundMode(tester), ShellLayoutMode.open);
    expect(container.read(overviewViewModelProvider).hasValue, isTrue);

    container.read(overviewViewModelProvider.notifier).requestHistory();
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
    expect(find.byType(TransactionsFlow), findsOneWidget);
    expect(find.byType(OverviewScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  }, timeout: uiTestTimeout);

  testWidgets('a phone overview history request selects the History tab '
      'with no back control', (tester) async {
    final factory = _GatedStoreFactory();
    final container = containerWith(factory);
    await tester.pumpWidget(
      hostedBoundIn(tester, container, const Size(400, 800)),
    );
    factory.succeed();
    await tester.pumpAndSettle();
    expect(boundMode(tester), ShellLayoutMode.phone);
    expect(container.read(overviewViewModelProvider).hasValue, isTrue);

    container.read(overviewViewModelProvider.notifier).requestHistory();
    await tester.pumpAndSettle();

    expect(
      container.read(selectedDestinationProvider),
      ShellDestination.history,
    );
    expect(find.byType(TransactionsFlow), findsOneWidget);
    expect(find.byType(OverviewScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  }, timeout: uiTestTimeout);
}
