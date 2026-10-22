import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/stats/trends/trends_intent.dart';

enum TrendsBreakdownScope {
  wholePeriod,
  selectedPeriod;

  String label(TrendsMode mode) => switch (this) {
    TrendsBreakdownScope.wholePeriod => 'Whole period',
    TrendsBreakdownScope.selectedPeriod => switch (mode) {
      TrendsMode.month => 'Selected month',
      TrendsMode.year => 'Selected year',
    },
  };
}

class TrendsBreakdownScopeNotifier extends Notifier<TrendsBreakdownScope> {
  @override
  TrendsBreakdownScope build() => TrendsBreakdownScope.wholePeriod;

  void setScope(TrendsBreakdownScope scope) {
    if (scope == state) return;
    state = scope;
  }
}

final trendsBreakdownScopeProvider =
    NotifierProvider.autoDispose<
      TrendsBreakdownScopeNotifier,
      TrendsBreakdownScope
    >(TrendsBreakdownScopeNotifier.new);
