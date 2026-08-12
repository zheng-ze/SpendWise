import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/persistence/persistence_processor.dart';

sealed class AppPhase {
  const AppPhase();
}

class Loading extends AppPhase {
  const Loading();
}

class Ready extends AppPhase {
  const Ready({required this.ledger, required this.persistence});

  final Ledger ledger;

  final PersistenceProcessor persistence;
}

class Failed extends AppPhase {
  const Failed(this.error, [this.stackTrace]);

  final Object error;

  final StackTrace? stackTrace;
}
