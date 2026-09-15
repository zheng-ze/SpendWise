import 'package:domain/domain.dart';
import 'package:sync/sync.dart';

/// What the store is doing about a failed save, so the banner stops claiming
/// "retrying" once the store has given up on the current attempt.
enum SaveBannerState { clear, retrying, failedWillRetry, permanentlyFailed }

typedef SaveErrorHandler = void Function(SaveBannerState state);

/// [enqueue] is fire-and-forget: an implementation may debounce and coalesce
/// within its own window, so the only durability promise is [flushNow], which
/// returns once everything enqueued before the call has landed.
abstract class LedgerStore {
  Future<LedgerState> load();

  Future<void> seedIfFirstLaunch(List<LedgerChange> changes);

  Future<void> start();

  /// Unstamped path: local publications (an empty stamps map counts as
  /// unstamped at the processor). Stamped sync publications go to
  /// [enqueueStamped].
  void enqueue(List<LedgerChange> changes);

  /// Stamped variant of [enqueue] for sync publications carrying per-row
  /// version vectors. Unstamped publications keep the existing [enqueue]
  /// bump path.
  void enqueueStamped(
    List<LedgerChange> changes,
    Map<SyncRowID, VersionVector> stamps,
  );

  Future<void> flushNow();

  Future<void> setErrorHandler(SaveErrorHandler handler);
}
