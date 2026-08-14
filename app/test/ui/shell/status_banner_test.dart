import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';
import 'package:spendwise/boot/banner_state.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/persistence/ledger_store.dart';
import 'package:spendwise/ui/shell/status_banner.dart';

void main() {
  late BannerState banner;

  // Riverpod disposes the notifier with the container, so the test must not.
  setUp(() => banner = BannerState());

  Future<ProviderContainer> pumpBanner(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [bannerStateProvider.overrideWith((ref) => banner)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [StatusBanner()])),
        ),
      ),
    );
    return container;
  }

  testWidgets('a healthy run renders nothing', (tester) async {
    await pumpBanner(tester);

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a save problem stays visible until the store reports clear', (
    tester,
  ) async {
    await pumpBanner(tester);

    banner.receiveSaveState(SaveBannerState.retrying);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save changes, retrying"), findsOneWidget);

    // Well past any snackbar-length timeout, since this is an ongoing
    // condition rather than a notification.
    await tester.pump(const Duration(seconds: 30));
    expect(find.text("Couldn't save changes, retrying"), findsOneWidget);

    banner.receiveSaveState(SaveBannerState.clear);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save changes, retrying"), findsNothing);
  });

  testWidgets('a plan error outranks a save problem', (tester) async {
    await pumpBanner(tester);

    banner.receiveSaveState(SaveBannerState.failedWillRetry);
    banner.receivePlanErrors([
      PlanFailure(
        planID: '11111111-1111-4111-8111-111111111111',
        occurrence: DateTime.utc(2024, 5, 1),
        error: const ZeroAmount(),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.text("A recurring plan couldn't add its entry"),
      findsOneWidget,
    );
    expect(
      find.text("Couldn't save changes, will retry shortly"),
      findsNothing,
    );

    // The save problem is still outstanding, so it takes the banner back once
    // the plan error has run its dismissal timer out.
    await tester.pump(const Duration(seconds: 5));
    expect(
      find.text("Couldn't save changes, will retry shortly"),
      findsOneWidget,
    );
  });

  testWidgets('the banner sits at the bottom of its stack', (tester) async {
    await pumpBanner(tester);

    banner.receiveSaveState(SaveBannerState.retrying);
    await tester.pumpAndSettle();

    final banners = tester.getRect(
      find.text("Couldn't save changes, retrying"),
    );
    expect(
      banners.center.dy,
      greaterThan(tester.getRect(find.byType(Stack).first).center.dy),
    );
  });
}
