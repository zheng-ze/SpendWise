import 'package:domain/domain.dart';

enum AccountFormKind { account, subpocket }

/// Returns the active accounts a pocket can be created under.
List<Account> pocketableParents(LedgerState state) {
  // Pockets can never live under a card, so this excludes cards rather
  // than trusting the caller to filter them out.
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
