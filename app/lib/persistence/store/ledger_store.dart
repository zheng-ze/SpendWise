import 'package:domain/domain.dart';

// MARK: - Save State

enum SaveBannerState { clear, retrying, failedWillRetry }

typedef SaveErrorHandler = void Function(SaveBannerState state);

// MARK: - Store

abstract class LedgerStore {
  Future<LedgerState> load();

  Future<void> seedIfFirstLaunch(List<LedgerChange> changes);

  Future<void> start();

  void enqueue(List<LedgerChange> changes);

  Future<void> flushNow();

  Future<void> setErrorHandler(SaveErrorHandler handler);
}
