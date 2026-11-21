import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/seed_data.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/analysis_queries.dart';
import 'package:spendwise/ledger/ledger.dart';

class ManualRunner {
  final List<Completer<List<AnalysisItem>>> pending = [];

  int calls = 0;

  Future<List<AnalysisItem>> call(LedgerState state) {
    calls++;
    final completer = Completer<List<AnalysisItem>>();
    pending.add(completer);
    return completer.future;
  }
}

({
  Ledger ledger,
  AnalysisCache cache,
  AnalysisQueries queries,
  ManualRunner runner,
})
setupAnalysis({DateTime? today}) {
  final ledger = Ledger();
  final runner = ManualRunner();
  final cache = AnalysisCache(runner: runner.call)
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = AnalysisQueries(
    ledger: ledger,
    cache: cache,
    today: today ?? DateTime.utc(2027, 5, 15),
  );
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  return (ledger: ledger, cache: cache, queries: queries, runner: runner);
}

Future<AnalysisQueries> setupSeededAnalysis({required DateTime today}) async {
  final state = LedgerState();
  buildSeed(state, today: today);
  final ledger = Ledger(state: state);
  final cache = AnalysisCache(runner: (s) async => Accounting.analysisItems(s))
    ..start(ledger.bus, sourceRevision: () => ledger.revision);
  final queries = AnalysisQueries(ledger: ledger, cache: cache, today: today);
  addTearDown(() async {
    queries.dispose();
    await cache.dispose();
  });
  await pumpEventQueue();
  return queries;
}

Future<void> settle(
  ManualRunner runner,
  Ledger ledger, {
  List<AnalysisItem>? items,
}) async {
  runner.pending.last.complete(items ?? Accounting.analysisItems(ledger.state));
  await pumpEventQueue();
}

String testId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

void silenceDebugPrint() {
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  addTearDown(() => debugPrint = original);
}

Future<void> withSilencedDebugPrint(Future<void> Function() body) async {
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  try {
    await body();
  } finally {
    debugPrint = original;
  }
}
