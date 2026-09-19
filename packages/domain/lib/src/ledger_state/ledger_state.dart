import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:domain/src/accounts/account.dart';
import 'package:domain/src/accounts/account_type.dart';
import 'package:domain/src/accounts/money_source.dart';
import 'package:domain/src/accounts/sub_pocket.dart';
import 'package:domain/src/budgets/budget.dart';
import 'package:domain/src/budgets/limit_event.dart';
import 'package:domain/src/entries/category_kind.dart';
import 'package:domain/src/entries/entry.dart';
import 'package:domain/src/entries/transaction_category.dart';
import 'package:domain/src/ids.dart';
import 'package:domain/src/ledger_change.dart';
import 'package:domain/src/ledger_error.dart';
import 'package:domain/src/lifecycle_state.dart';
import 'package:domain/src/plans/plan_failure.dart';
import 'package:domain/src/plans/plan_resolution.dart';
import 'package:domain/src/plans/recurring_plan.dart';
import 'package:domain/src/time/calendar_day.dart';
import 'package:domain/src/time/year_month.dart';

part 'ledger_state_adopt.dart';
part 'ledger_state_budgets.dart';
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
    Map<String, Budget>? budgets,
  }) : _moneySources = {...?moneySources},
       _entries = {...?entries},
       _categories = {...?categories},
       _plans = {...?plans},
       _budgets = {...?budgets};

  /// Throws on a corrupted change stream.
  LedgerState.replaying(List<LedgerChange> changes)
    : _moneySources = {},
      _entries = {},
      _categories = {},
      _plans = {},
      _budgets = {} {
    apply(changes);

    // Calls assertInvariants() directly instead of going through the
    // debug-only _checked wrapper that every mutator uses.
    assertInvariants();
  }

  final Map<String, MoneySource> _moneySources;

  final Map<String, Entry> _entries;

  final Map<String, TransactionCategory> _categories;

  final Map<String, RecurringPlan> _plans;

  final Map<String, Budget> _budgets;

  /// Unmodifiable, so a caller cannot bypass the mutators' guards by writing
  /// through the returned map.
  Map<String, MoneySource> get moneySources =>
      UnmodifiableMapView(_moneySources);

  Map<String, Entry> get entries => UnmodifiableMapView(_entries);

  Map<String, TransactionCategory> get categories =>
      UnmodifiableMapView(_categories);

  Map<String, RecurringPlan> get plans => UnmodifiableMapView(_plans);

  Map<String, Budget> get budgets => UnmodifiableMapView(_budgets);

  // Previous settled lifecycles, for the one check that judges a transition
  // rather than a state. Written only from inside an `assert`.
  Map<String, LifecycleState>? _lifecycleAtLastCheck;

  // The closure form keeps the check out of release builds entirely.
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

  // Edit must not change lifecycle. Only delete/restore/purge may.
  LifecycleState _editableLifecycle(LifecycleState stored) => stored;
}
