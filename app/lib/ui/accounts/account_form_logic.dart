import 'package:domain/domain.dart';

enum AccountFormKind { account, subpocket }

/// Pockets can never live under a card, so the parent picker and the save
/// path both filter through this rather than trusting the caller.
List<Account> pocketableParents(LedgerState state) {
  return state.activeAccounts
      .where((account) => account.type != AccountType.card)
      .toList();
}

bool canSaveAccountForm({
  required AccountFormKind kind,
  required String name,
  required String? parentId,
}) {
  if (name.trim().isEmpty) return false;
  if (kind == AccountFormKind.subpocket && parentId == null) return false;
  return true;
}
