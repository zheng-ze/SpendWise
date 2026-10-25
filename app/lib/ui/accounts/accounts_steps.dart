// MARK: - Steps
sealed class AccountsStep {}

// MARK: - Form Steps
class AccountFormRequested extends AccountsStep {}

class SourceEditRequested extends AccountsStep {
  SourceEditRequested(this.holderId);

  final String holderId;
}

class PickParentRequested extends AccountsStep {}

class AccountFormSaved extends AccountsStep {}

class SourceEditFormSaved extends AccountsStep {}

// MARK: - Navigation Steps
class AccountOpened extends AccountsStep {
  AccountOpened(this.title, this.scopeIDs);

  final String title;
  final Set<String> scopeIDs;
}

class AccountAloneOpened extends AccountsStep {
  AccountAloneOpened(this.title, this.scopeIDs);

  final String title;
  final Set<String> scopeIDs;
}

class PocketOpened extends AccountsStep {
  PocketOpened(this.title, this.scopeIDs);

  final String title;
  final Set<String> scopeIDs;
}

class AccountDetailRequested extends AccountsStep {}
