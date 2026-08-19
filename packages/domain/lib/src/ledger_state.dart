import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:domain/src/account.dart';
import 'package:domain/src/account_type.dart';
import 'package:domain/src/entry.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/ledger_change.dart';
import 'package:domain/src/ledger_error.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:domain/src/money_source.dart';
import 'package:domain/src/plan_failure.dart';
import 'package:domain/src/plan_resolution.dart';
import 'package:domain/src/recurring_plan.dart';
import 'package:domain/src/sub_pocket.dart';
import 'package:domain/src/transaction_category.dart';

part 'ledger_state_categories.dart';
part 'ledger_state_entries.dart';
part 'ledger_state_holders.dart';
part 'ledger_state_invariants.dart';
part 'ledger_state_plans.dart';
part 'ledger_state_purge.dart';
part 'ledger_state_queries.dart';
part 'ledger_state_replay.dart';

class LedgerState {
  LedgerState({
    Map<String, MoneySource>? moneySources,
    Map<String, Entry>? entries,
    Map<String, TransactionCategory>? categories,
    Map<String, RecurringPlan>? plans,
  }) : _moneySources = {...?moneySources},
       _entries = {...?entries},
       _categories = {...?categories},
       _plans = {...?plans};

  /// Throws on a corrupted change stream.
  LedgerState.replaying(List<LedgerChange> changes)
    : _moneySources = {},
      _entries = {},
      _categories = {},
      _plans = {} {
    apply(changes);

    // Calls assertInvariants() directly instead of going through the
    // debug-only _checked wrapper that every mutator uses.
    assertInvariants();
  }

  final Map<String, MoneySource> _moneySources;

  final Map<String, Entry> _entries;

  final Map<String, TransactionCategory> _categories;

  final Map<String, RecurringPlan> _plans;

  /// Views, not the tables. Mutators are one of only two write paths, so the
  /// guards cannot be walked around and the invariants have a single choke
  /// point. Replay is the other, and it deliberately skips both.
  Map<String, MoneySource> get moneySources =>
      UnmodifiableMapView(_moneySources);

  Map<String, Entry> get entries => UnmodifiableMapView(_entries);

  Map<String, TransactionCategory> get categories =>
      UnmodifiableMapView(_categories);

  Map<String, RecurringPlan> get plans => UnmodifiableMapView(_plans);

  /// Previous settled lifecycles, for the one check that judges a transition
  /// rather than a state. Written only from inside an `assert`.
  Map<String, LifecycleState>? _lifecycleAtLastCheck;

  /// The closure form keeps the check out of release builds entirely.
  List<LedgerChange> _checked(List<LedgerChange> changes) {
    assert(() {
      _assertChecked();
      return true;
    }());
    return changes;
  }

  PlanResolution _checkedResolution(PlanResolution resolution) {
    assert(() {
      _assertChecked();
      return true;
    }());
    return resolution;
  }

  /// Edit must not change lifecycle. Only delete/restore/purge may.
  LifecycleState _editableLifecycle(LifecycleState stored) => stored;
}
