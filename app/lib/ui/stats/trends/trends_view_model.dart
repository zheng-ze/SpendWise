import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ui/common/base/ledger_backed_notifier.dart';
import 'package:spendwise/ui/stats/trends/trends_body.dart';
import 'package:spendwise/ui/stats/trends/trends_intent.dart';
import 'package:spendwise/ui/stats/trends/trends_projection.dart';

// MARK: - ViewModel
abstract class TrendsViewModel {
  void setKind(TrendsKind kind);
  void setMode(TrendsMode mode);
  void selectSlot(int index);
  void previousPage();
  void nextPage();
  void retry();
}

// MARK: - Notifier
class TrendsNotifier extends AsyncNotifier<TrendsBody>
    with LedgerBackedNotifier<TrendsBody>
    implements TrendsViewModel {
  @override
  TrendsBody build() {
    final revision = ledger.revision;
    final queries = ref.watch(analysisQueriesProvider);
    if (queries == null) {
      throw StateError('$runtimeType requires analysis queries.');
    }
    return projectTrends(
      queries: queries,
      intent: ref.watch(trendsIntentProvider),
      today: ref.watch(todayProvider),
      ledgerRevision: revision,
    );
  }

  @override
  void setKind(TrendsKind kind) => _intent.setKind(kind, _context());

  @override
  void setMode(TrendsMode mode) => _intent.setMode(mode, _context());

  @override
  void selectSlot(int index) => _intent.selectSlot(index, _context());

  @override
  void previousPage() => _intent.previousPage(_context());

  @override
  void nextPage() => _intent.nextPage(_context());

  @override
  void retry() => ref.read(analysisQueriesProvider)?.retry();

  TrendsIntentNotifier get _intent => ref.read(trendsIntentProvider.notifier);

  TrendsContext _context() {
    final bounds = switch (state) {
      AsyncData(:final value) => value.bounds,
      _ => null,
    };
    return TrendsContext(
      currentMonth: monthSerial(ref.read(todayProvider)),
      bounds: bounds,
    );
  }
}

final trendsViewModelProvider =
    AsyncNotifierProvider.autoDispose<TrendsNotifier, TrendsBody>(
      TrendsNotifier.new,
    );
