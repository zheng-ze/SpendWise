import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';

class LedgerSession {
  const LedgerSession({required this.ledger, required this.analysisCache});

  final Ledger ledger;
  final AnalysisCache analysisCache;
}
