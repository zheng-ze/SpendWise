import 'package:domain/domain.dart';
import 'package:sync/sync.dart';

enum SaveBannerState { clear, retrying, failedWillRetry, permanentlyFailed }

typedef SaveErrorHandler = void Function(SaveBannerState state);

abstract class LedgerStore {
  Future<LedgerState> load();

  Future<void> seedIfFirstLaunch(List<LedgerChange> changes);

  Future<void> start();

  void enqueue(List<LedgerChange> changes);

  void enqueueStamped(
    List<LedgerChange> changes,
    Map<SyncRowID, VersionVector> stamps,
  );

  Future<void> flushNow();

  Future<void> setErrorHandler(SaveErrorHandler handler);
}
