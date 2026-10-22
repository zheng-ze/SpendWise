import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_detail_metadata.dart';

import '../../ledger/analysis_test_support.dart';
import 'trends_test_support.dart';

void main() {
  final today = DateTime.utc(2026, 10, 15);

  test(
    'metadata stays stable through ready, loading, failure and Retry',
    () async {
      final ledger = emptyTrendsLedger();
      addTrendsEntry(ledger, '-40', DateTime.utc(2026, 7, 4));
      addTrendsEntry(ledger, '-25', DateTime.utc(2026, 10, 2));
      final runner = ManualRunner();
      final harness = TrendsHarness(
        ledger: ledger,
        today: today,
        runner: runner.call,
      );
      await harness.settle();

      final initial = harness.container.read(trendsDetailMetadataProvider);
      expect(harness.body, isA<TrendsLoadingBody>());

      runner.pending.last.complete(Accounting.analysisItems(ledger.state));
      await harness.settle();
      expect(harness.body, isA<TrendsReadyBody>());
      expect(harness.container.read(trendsDetailMetadataProvider), initial);

      addTrendsEntry(ledger, '-10', DateTime.utc(2026, 10, 3));
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());
      expect(harness.container.read(trendsDetailMetadataProvider), initial);

      runner.pending.last.completeError(StateError('compute failed'));
      await harness.settle();
      expect(harness.body, isA<TrendsErrorBody>());
      expect(harness.container.read(trendsDetailMetadataProvider), initial);

      harness.viewModel.retry();
      await harness.settle();
      expect(harness.body, isA<TrendsLoadingBody>());
      expect(harness.container.read(trendsDetailMetadataProvider), initial);

      runner.pending.last.complete(Accounting.analysisItems(ledger.state));
      await harness.settle();
      expect(harness.body, isA<TrendsReadyBody>());
      expect(harness.container.read(trendsDetailMetadataProvider), initial);
      expect(initial.title, 'October 2026');
    },
  );
}
