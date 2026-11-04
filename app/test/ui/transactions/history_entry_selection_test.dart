import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/sheets/app_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/edit_entry_presenter.dart';
import 'package:spendwise/ui/transactions/history_entry_selection.dart';

import '../../support/edit_entry_harness.dart';
import '../../support/ui_test_timeout.dart';

final _layoutModeProvider = StateProvider<ShellLayoutMode>(
  (ref) => ShellLayoutMode.open,
);

final _layoutOverride = shellLayoutModeProvider.overrideWith(
  (ref) => ref.watch(_layoutModeProvider),
);

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [_layoutOverride]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('shrinking to phone clears the selection', () {
    final container = _container();
    final subscription = container.listen(
      historyEntrySelectionProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    container.read(historyEntrySelectionProvider.notifier).select('entry-a');
    expect(container.read(historyEntrySelectionProvider), 'entry-a');
    container.read(_layoutModeProvider.notifier).state = ShellLayoutMode.phone;

    expect(container.read(historyEntrySelectionProvider), isNull);
  });

  test('re-selecting the same id keeps one selection', () {
    final container = _container();
    final subscription = container.listen(
      historyEntrySelectionProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final notifier = container.read(historyEntrySelectionProvider.notifier);

    notifier.select('entry-a');
    notifier.select('entry-a');

    expect(container.read(historyEntrySelectionProvider), 'entry-a');
  });

  test('the selection is disposed when nothing listens', () async {
    final container = _container();
    final subscription = container.listen(
      historyEntrySelectionProvider,
      (_, _) {},
    );
    container.read(historyEntrySelectionProvider.notifier).select('entry-a');
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(historyEntrySelectionProvider), isNull);
  });

  testWidgets('openEditEntry clears a matching selection and opens one sheet', (
    tester,
  ) async {
    final entry = editableEntry();
    final host = await pumpEditHost(tester, editLedger([entry]));
    final subscription = host.container.listen(
      historyEntrySelectionProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    host.container
        .read(historyEntrySelectionProvider.notifier)
        .select(entry.id);

    unawaited(
      openEditEntry(context: host.context, ref: host.ref, entryId: entry.id),
    );
    await tester.pumpAndSettle();

    expect(host.container.read(historyEntrySelectionProvider), isNull);
    expect(find.byType(AppSheet), findsOneWidget);
  }, timeout: uiTestTimeout);

  testWidgets('openEditEntry keeps a selection of another entry', (
    tester,
  ) async {
    final entry = editableEntry();
    final host = await pumpEditHost(tester, editLedger([entry]));
    final subscription = host.container.listen(
      historyEntrySelectionProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    host.container
        .read(historyEntrySelectionProvider.notifier)
        .select('other-entry');

    unawaited(
      openEditEntry(context: host.context, ref: host.ref, entryId: entry.id),
    );
    await tester.pumpAndSettle();

    expect(host.container.read(historyEntrySelectionProvider), 'other-entry');
  }, timeout: uiTestTimeout);
}
