import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/app_boot.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/shell/desktop_sidebar.dart';
import 'package:spendwise/ui/shell/shell_destinations.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/settings/settings_root_view_model.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

import '../../support/ui_test_timeout.dart';

// MARK: - Constants
const _syncReadyLabel = 'Sync ready';
const _syncUnavailableLabel = 'Sync unavailable';
const _syncTimestampPattern = r'Last synced|\b\d{1,2}:\d{2}\b|\b20\d{2}\b';

final _mutableHostedSyncStatusProvider =
    NotifierProvider<_MutableHostedSyncStatusNotifier, HostedSyncStatus>(
      _MutableHostedSyncStatusNotifier.new,
    );

class _MutableHostedSyncStatusNotifier extends Notifier<HostedSyncStatus> {
  @override
  HostedSyncStatus build() => const HostedSyncNoSelection();

  void setStatus(HostedSyncStatus status) => state = status;
}

class _RecordingAppBoot extends AppBoot {
  _RecordingAppBoot(this.calls)
    : super(createStore: _createStore, seedChanges: _emptyChanges);

  final List<String> calls;
  HostedSyncStatus status = const HostedSyncUnavailable();

  static Future<Never> _createStore() async => throw StateError('unused');

  static List<LedgerChange> _emptyChanges() => [];

  @override
  HostedSyncStatus get syncStatus => status;

  @override
  Future<void> refreshSyncStatus() {
    calls.add('refresh');
    return Future.value();
  }
}

class _RecordingSettingsRootNotifier extends SettingsRootNotifier {
  _RecordingSettingsRootNotifier(this.calls);

  final List<String> calls;

  @override
  void requestRepair() => calls.add('repair');

  @override
  void requestStartHostedEnrollment() => calls.add('enrollment');

  @override
  void requestResumeFreshEnrollment() => calls.add('resume');
}

void main() {
  testWidgets('sidebar sync label updates when hosted status changes', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        hostedSyncStatusProvider.overrideWith(
          (ref) => ref.watch(_mutableHostedSyncStatusProvider),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSpendWiseTheme(Brightness.light),
          home: Scaffold(
            body: DesktopSidebar(
              selected: ShellDestination.overview,
              onDestinationSelected: (_) {},
              onAdd: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sync not configured'), findsOneWidget);
    container
        .read(_mutableHostedSyncStatusProvider.notifier)
        .setStatus(const HostedSyncReady());
    await tester.pump();

    expect(find.text(_syncReadyLabel), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('sidebar sync line starts no operations or timestamp', (
    tester,
  ) async {
    final operationCalls = <String>[];
    final appBoot = _RecordingAppBoot(operationCalls);
    final settingsViewModel = _RecordingSettingsRootNotifier(operationCalls);
    final container = ProviderContainer(
      overrides: [
        appBootProvider.overrideWith((ref) => appBoot),
        settingsRootViewModelProvider.overrideWith(() => settingsViewModel),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildSpendWiseTheme(Brightness.light),
          home: Scaffold(
            body: DesktopSidebar(
              selected: ShellDestination.overview,
              onDestinationSelected: (_) {},
              onAdd: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text(_syncUnavailableLabel), findsOneWidget);

    appBoot.status = const HostedSyncReady();
    appBoot.notifyListeners();
    await tester.pump();

    expect(find.text(_syncReadyLabel), findsOneWidget);
    expect(find.textContaining(RegExp(_syncTimestampPattern)), findsNothing);
    expect(operationCalls, isEmpty);
  }, timeout: uiTestTimeout);

  for (final scale in [2.0, 3.0]) {
    testWidgets(
      'large sidebar labels fit and remain tappable at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final selected = <ShellDestination>[];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildSpendWiseTheme(Brightness.light),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.centerLeft,
                    child: DesktopSidebar(
                      selected: ShellDestination.overview,
                      onDestinationSelected: selected.add,
                      onAdd: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        for (final destination in ShellDestination.values) {
          final label = find.text(destinationLabels[destination]!);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          final item = find.ancestor(of: label, matching: find.byType(InkWell));
          final labelRect = tester.getRect(label);
          final itemRect = tester.getRect(item);
          expect(labelRect.left, greaterThanOrEqualTo(itemRect.left));
          expect(labelRect.right, lessThanOrEqualTo(itemRect.right));
          expect(labelRect.top, greaterThanOrEqualTo(itemRect.top));
          expect(labelRect.bottom, lessThanOrEqualTo(itemRect.bottom));

          if (destination == ShellDestination.overview ||
              destination == ShellDestination.settings) {
            final paragraph = tester.renderObject<RenderParagraph>(label);
            final lines = paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: destinationLabels[destination]!.length,
              ),
            );
            expect(lines.length, greaterThan(1));
          }

          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(selected.last, destination);
          expect(tester.takeException(), isNull);
        }
        expect(selected, ShellDestination.values);
      },
      timeout: uiTestTimeout,
    );
  }
}
