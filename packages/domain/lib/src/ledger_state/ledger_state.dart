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
import 'package:domain/src/entries/system_entry_kind.dart';
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

part 'mutators/ledger_state_accounts.dart';
part 'mutators/ledger_state_adopt.dart';
part 'mutators/ledger_state_budgets.dart';
part 'mutators/ledger_state_categories.dart';
part 'mutators/ledger_state_entries.dart';
part 'mutators/ledger_state_entry_validation.dart';
part 'mutators/ledger_state_holders.dart';
part 'invariants/ledger_state_invariants.dart';
part 'invariants/ledger_state_invariants_budgets.dart';
part 'invariants/ledger_state_invariants_categories.dart';
part 'invariants/ledger_state_invariants_entries.dart';
part 'invariants/ledger_state_invariants_holders.dart';
part 'invariants/ledger_state_invariants_plans.dart';
part 'mutators/ledger_state_plan_resolution.dart';
part 'mutators/ledger_state_plans.dart';
part 'mutators/ledger_state_pockets.dart';
part 'mutators/ledger_state_purge.dart';
part 'queries/ledger_state_queries.dart';
part 'mutators/ledger_state_replay.dart';
part 'mutators/ledger_state_sweep.dart';

class LedgerState {
  // MARK: - Construction

  LedgerState({
    Map<String, MoneySource>? moneySources,
    Map<String, Entry>? entries,
    Map<String, Entry>? binnedEntries,
    Map<String, TransactionCategory>? categories,
    Map<String, RecurringPlan>? plans,
    Map<String, Budget>? budgets,
  }) : _moneySources = {...?moneySources},
       _entries = {...?entries},
       _binnedEntries = {...?binnedEntries},
       _categories = {...?categories},
       _plans = {...?plans},
       _budgets = {...?budgets};

  LedgerState.replaying(List<LedgerChange> changes)
    : _moneySources = {},
      _entries = {},
      _binnedEntries = {},
      _categories = {},
      _plans = {},
      _budgets = {} {
    apply(changes);

    assertInvariants();
  }

  // MARK: - State

  final Map<String, MoneySource> _moneySources;

  final Map<String, Entry> _entries;

  final Map<String, Entry> _binnedEntries;

  final Map<String, TransactionCategory> _categories;

  final Map<String, RecurringPlan> _plans;

  final Map<String, Budget> _budgets;

  Map<String, LifecycleState>? _lifecycleAtLastCheck;

  // MARK: - Views

  Map<String, MoneySource> get moneySources =>
      UnmodifiableMapView(_moneySources);

  Map<String, Entry> get entries => UnmodifiableMapView(_entries);

  Map<String, Entry> get binnedEntries => UnmodifiableMapView(_binnedEntries);

  Map<String, TransactionCategory> get categories =>
      UnmodifiableMapView(_categories);

  Map<String, RecurringPlan> get plans => UnmodifiableMapView(_plans);

  Map<String, Budget> get budgets => UnmodifiableMapView(_budgets);

  // MARK: - Checks

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

  LifecycleState _editableLifecycle(LifecycleState stored) => stored;
}
