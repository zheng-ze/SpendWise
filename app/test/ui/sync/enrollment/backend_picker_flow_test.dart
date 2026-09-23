import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_flow.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';

final class FakeBackendSelectionWriter implements BackendSelectionWriter {
  final List<({SyncBackendKind backend, String? endpoint})> calls = [];

  @override
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) async {
    calls.add((backend: backend, endpoint: endpoint));
  }
}

Future<ProviderContainer> pumpFlow(
  WidgetTester tester,
  FakeBackendSelectionWriter writer, {
  required VoidCallback onHostedReady,
}) async {
  final container = ProviderContainer(
    overrides: [
      backendPickerViewModelProvider.overrideWith(
        () => BackendPickerNotifier(writer: writer),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: BackendPickerFlow(onHostedReady: onHostedReady)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('builds the picker as its root', (tester) async {
    await pumpFlow(tester, FakeBackendSelectionWriter(), onHostedReady: () {});

    expect(find.byType(BackendPickerFlow), findsOneWidget);
    expect(find.byType(BackendPickerScreen), findsOneWidget);
  });

  testWidgets('hosted-ready invokes the hosted callback and clears the step', (
    tester,
  ) async {
    var hostedCalls = 0;
    final container = await pumpFlow(
      tester,
      FakeBackendSelectionWriter(),
      onHostedReady: () => hostedCalls += 1,
    );

    await container
        .read(backendPickerViewModelProvider.notifier)
        .continueWithSelection();
    await tester.pumpAndSettle();

    expect(hostedCalls, 1);
    expect(
      container.read(backendPickerViewModelProvider).step,
      isNull,
      reason: 'the Flow clears the step so a rebuild never replays it',
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(BackendPickerScreen), findsOneWidget);
  });

  testWidgets('custom-unavailable shows the affordance, clears the step, '
      'and never invokes the hosted callback', (tester) async {
    var hostedCalls = 0;
    final writer = FakeBackendSelectionWriter();
    final container = await pumpFlow(
      tester,
      writer,
      onHostedReady: () => hostedCalls += 1,
    );
    final viewModel = container.read(backendPickerViewModelProvider.notifier);

    viewModel.selectBackend(SyncBackendKind.custom);
    viewModel.updateEndpoint('https://sync.example.com/sync');
    await viewModel.continueWithSelection();
    await tester.pump();

    expect(writer.calls, hasLength(1));
    expect(writer.calls.single.backend, SyncBackendKind.custom);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Custom servers are not yet available.'), findsOneWidget);
    expect(hostedCalls, 0);
    expect(
      container.read(backendPickerViewModelProvider).step,
      isNull,
      reason: 'the Flow clears the step so a rebuild never replays it',
    );
    expect(find.byType(BackendPickerScreen), findsOneWidget);
  });
}
