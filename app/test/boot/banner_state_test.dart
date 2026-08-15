import 'package:domain/domain.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/banner_state.dart';
import 'package:spendwise/persistence/ledger_store.dart';

PlanFailure failure(String planID) => PlanFailure(
  planID: planID,
  occurrence: DateTime.utc(2026, 1, 1),
  error: UnknownPlan(planID),
);

void main() {
  test('startsWithNoBanner', () {
    expect(BannerState().message, isNull);
  });

  test('retryingShowsExactSaveMessage', () {
    final banner = BannerState()..receiveSaveState(SaveBannerState.retrying);
    expect(banner.message, "Couldn't save changes, retrying");
  });

  test('failedWillRetryShowsExactSaveMessage', () {
    final banner = BannerState()
      ..receiveSaveState(SaveBannerState.failedWillRetry);
    expect(banner.message, "Couldn't save changes, will retry shortly");
  });

  test('clearSaveStateShowsNoBanner', () {
    final banner = BannerState()
      ..receiveSaveState(SaveBannerState.retrying)
      ..receiveSaveState(SaveBannerState.clear);
    expect(banner.message, isNull);
  });

  test('planErrorTakesPrecedenceOverSaveStateMessage', () {
    fakeAsync((async) {
      final banner = BannerState()
        ..receiveSaveState(SaveBannerState.retrying)
        ..receivePlanErrors([failure('plan-1')]);
      expect(banner.message, "A recurring plan couldn't add its entry");
    });
  });

  test('incomingClearDoesNotDismissAShowingPlanError', () {
    fakeAsync((async) {
      final banner = BannerState()..receivePlanErrors([failure('plan-1')]);
      banner.receiveSaveState(SaveBannerState.clear);
      expect(banner.message, "A recurring plan couldn't add its entry");
    });
  });

  test('oneDistinctPlanIdSaysSingularEvenWithMultipleFailures', () {
    fakeAsync((async) {
      final banner = BannerState()
        ..receivePlanErrors([failure('plan-1'), failure('plan-1')]);
      expect(banner.message, "A recurring plan couldn't add its entry");
    });
  });

  test('threeDistinctPlanIdsSaysPluralWithCount', () {
    fakeAsync((async) {
      final banner = BannerState()
        ..receivePlanErrors([
          failure('plan-1'),
          failure('plan-2'),
          failure('plan-3'),
        ]);
      expect(banner.message, "3 recurring plans couldn't add their entries");
    });
  });

  test('planErrorAutoDismissesAfterFourSeconds', () {
    fakeAsync((async) {
      final banner = BannerState()..receivePlanErrors([failure('plan-1')]);
      async.elapse(const Duration(seconds: 4));
      expect(banner.message, isNull);
    });
  });

  test(
    'refireCancelsThePendingTimerAndTheStaleTimerDoesNotClearTheNewMessage',
    () {
      fakeAsync((async) {
        final banner = BannerState()..receivePlanErrors([failure('plan-1')]);
        async.elapse(const Duration(seconds: 3));

        banner.receivePlanErrors([failure('plan-1'), failure('plan-2')]);
        // The stale timer from the first call must not clear the newer message.
        async.elapse(const Duration(seconds: 2));
        expect(banner.message, "2 recurring plans couldn't add their entries");

        async.elapse(const Duration(seconds: 3));
        expect(banner.message, isNull);
      });
    },
  );

  test('notifiesListenersOnEveryObservableChange', () {
    fakeAsync((async) {
      final banner = BannerState();
      var notifications = 0;
      banner.addListener(() => notifications++);

      banner.receiveSaveState(SaveBannerState.retrying);
      expect(notifications, 1);

      banner.receivePlanErrors([failure('plan-1')]);
      expect(notifications, 2);

      async.elapse(const Duration(seconds: 4));
      expect(notifications, 3);
    });
  });
}
