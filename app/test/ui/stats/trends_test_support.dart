import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/settings/display_preferences.dart';
import 'package:spendwise/settings/display_preferences_providers.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_view_model.dart';

const checkingSourceID = '11111111-1111-1111-1111-111111111111';
const foodCategoryID = '33333333-3333-3333-3333-333333333333';
const payCategoryID = '44444444-4444-4444-4444-444444444444';
const hiddenCategoryID = '66666666-6666-6666-6666-666666666666';

int _entryCounter = 0;

Ledger emptyTrendsLedger() {
  final ledger = Ledger();
  ledger.addAccount(
    Account(id: checkingSourceID, name: 'Checking', type: AccountType.checking),
  );
  for (final category in [
    _category(foodCategoryID, 'Food', CategoryKind.expense, analysed: true),
    _category(payCategoryID, 'Pay', CategoryKind.income, analysed: true),
    _category(
      hiddenCategoryID,
      'Hidden',
      CategoryKind.expense,
      analysed: false,
    ),
  ]) {
    ledger.addCategory(category);
  }
  return ledger;
}

TransactionCategory _category(
  String id,
  String name,
  CategoryKind kind, {
  required bool analysed,
}) {
  return TransactionCategory(
    id: id,
    name: name,
    kind: kind,
    colorHex: '#000000',
    includeInAnalysis: analysed,
    parentID: null,
    symbol: 'tag',
  );
}

String addTrendsEntry(
  Ledger ledger,
  String amount,
  DateTime date, {
  String? categoryID,
}) {
  _entryCounter++;
  final id =
      'e0000000-0000-0000-0000-${_entryCounter.toString().padLeft(12, '0')}';
  final category =
      categoryID ?? (amount.startsWith('-') ? foodCategoryID : payCategoryID);
  ledger.addEntry(
    Entry(
      id: id,
      amount: Decimal.parse(amount),
      name: 'entry',
      sourceID: checkingSourceID,
      categoryID: category,
      date: date,
    ),
  );
  return id;
}

Ledger seededTrendsLedger(DateTime today) {
  final state = LedgerState();
  buildSeed(state, today: today);
  return Ledger(state: state);
}

class TrendsHarness {
  TrendsHarness({
    required this.ledger,
    required this.today,
    ComputeRunner? runner,
    DisplayPreferences? preferences,
    List<Override> overrides = const [],
  }) {
    container = ProviderContainer(
      overrides: [
        if (preferences != null)
          initialDisplayPreferencesProvider.overrideWithValue(preferences),
        ledgerProvider.overrideWithValue(ledger),
        clockProvider.overrideWithValue(() => today),
        analysisComputeRunnerProvider.overrideWithValue(
          runner ?? syncComputeRunner,
        ),
        ...overrides,
      ],
    );
    addTearDown(dispose);
    container.listen(trendsIntentProvider, (_, _) {});
    container.listen(trendsViewModelProvider, (_, _) {});
  }

  final Ledger ledger;
  late final ProviderContainer container;
  DateTime today;

  TrendsViewModel get viewModel =>
      container.read(trendsViewModelProvider.notifier);

  TrendsIntent get intent => container.read(trendsIntentProvider);

  TrendsBody get body =>
      container.read(trendsViewModelProvider).requireValue.body;

  TrendsStep? get step =>
      container.read(trendsViewModelProvider).requireValue.step;

  TrendsReadyBody get ready => body as TrendsReadyBody;

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
  }

  Future<void> settle() => pumpEventQueue();

  Future<void> setToday(DateTime next) async {
    today = next;
    container.invalidate(todayProvider);
    await settle();
  }
}

Future<TrendsHarness> readyHarness({
  required Ledger ledger,
  required DateTime today,
}) async {
  final harness = TrendsHarness(ledger: ledger, today: today);
  await harness.settle();
  return harness;
}

const trendsPhoneSize = Size(320, 760);
const trendsShortPhoneSize = Size(320, 560);

Future<void> pumpTrends(
  WidgetTester tester, {
  required Ledger? ledger,
  required DateTime today,
  ComputeRunner? runner,
  DisplayPreferences? preferences,
  Widget home = const TrendsScreen(),
  Size size = trendsPhoneSize,
  Brightness brightness = Brightness.light,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      if (preferences != null)
        initialDisplayPreferencesProvider.overrideWithValue(preferences),
      ledgerProvider.overrideWithValue(ledger),
      clockProvider.overrideWithValue(() => today),
      analysisComputeRunnerProvider.overrideWithValue(
        runner ?? syncComputeRunner,
      ),
    ],
  );
  addTearDown(container.dispose);
  final app = MaterialApp(theme: buildSpendWiseTheme(brightness), home: home);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
