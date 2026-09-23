import 'dart:io';

import 'package:domain/domain.dart';

void main() {
  var assertsOn = false;
  assert(assertsOn = true);
  if (assertsOn) {
    stderr.writeln('PROBE_ASSERTS_ENABLED');
    exit(1);
  }

  final live = LedgerState();
  const holderID = '11111111-1111-4111-8111-111111111111';
  live.addAccount(
    Account(id: holderID, name: 'wallet', type: AccountType.savings),
  );

  final candidate = LedgerState(
    moneySources: live.moneySources,
    entries: live.entries,
    categories: live.categories,
    plans: live.plans,
    budgets: live.budgets,
  );
  candidate.apply([
    UpsertEntry(
      Entry(
        amount: Decimal.fromInt(-10),
        name: 'orphan',
        sourceID: '99999999-9999-4999-8999-999999999999',
      ),
    ),
  ]);

  try {
    candidate.assertInvariants();
  } on StateError {
    stdout.writeln('PROBE_PASS');
    return;
  }
  stderr.writeln('PROBE_VALIDATION_PASSED_INVALID_BATCH');
  exit(2);
}
