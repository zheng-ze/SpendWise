import 'package:domain/domain.dart';

/// What the store is doing about a failed save, so the banner stops claiming
/// "retrying" once the store has given up on the current attempt.
enum SaveBannerState { clear, retrying, failedWillRetry }

typedef SaveErrorHandler = void Function(SaveBannerState state);

/// [enqueue] is fire-and-forget: an implementation may debounce and coalesce
/// within its own window, so the only durability promise is [flushNow], which
/// returns once everything enqueued before the call has landed.
abstract class LedgerStore {
  Future<LedgerState> load();

  Future<void> start();

  void enqueue(List<LedgerChange> changes);

  Future<void> flushNow();

  Future<void> setErrorHandler(SaveErrorHandler handler);
}
