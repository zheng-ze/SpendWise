import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/backend_selection_writer.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_screen.dart';
import 'package:spendwise/ui/sync/enrollment/backend_picker/backend_picker_view_model.dart';

/// Hand-written stand-in for the persistence seam: counts writes without a
/// database, so the widget suite proves the screen drives the controller.
final class FakeBackendSelectionWriter implements BackendSelectionWriter {
  var calls = 0;

  @override
  Future<void> setBackendSelection({
    required SyncBackendKind backend,
    String? endpoint,
  }) async {
    calls += 1;
  }
}

Future<void> pumpPicker(
  WidgetTester tester,
  FakeBackendSelectionWriter writer,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backendPickerViewModelProvider.overrideWith(
          () => BackendPickerNotifier(writer: writer),
        ),
      ],
      child: const MaterialApp(home: BackendPickerScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows hosted and custom choices with the URL field hidden for hosted',
    (tester) async {
      await pumpPicker(tester, FakeBackendSelectionWriter());

      expect(find.text('Hosted sync'), findsOneWidget);
      expect(find.text('Custom server'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting custom reveals the URL field and reselecting hosted hides it',
    (tester) async {
      await pumpPicker(tester, FakeBackendSelectionWriter());

      await tester.tap(find.text('Custom server'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('Hosted sync'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('continue persists the hosted selection through the writer', (
    tester,
  ) async {
    final writer = FakeBackendSelectionWriter();
    await pumpPicker(tester, writer);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(writer.calls, 1);
  });
}
