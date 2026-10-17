import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/common/pickers/date_picker_sheet.dart';
import 'package:spendwise/ui/common/pickers/two_column_picker_sheet.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';
import 'package:spendwise/ui/transactions/entry/entry_form.dart';
import 'package:spendwise/ui/transactions/entry/new_entry_presenter.dart';
import 'package:spendwise/ui/transactions/receipt_scan/receipt_entry_coordinator.dart';

import 'new_entry_session_harness.dart';

const _staleSourceId = 'a0000000-0000-0000-0000-0000000000ff';

const _staleCategoryId = 'c0000000-0000-0000-0000-0000000000ff';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int pickerCount() => find.byType(PickerGroupBody).evaluate().length;

  group('Add-only dismissal closes the captured Add route', () {
    const modes = {
      'phone': (phoneSize, TargetPlatform.iOS),
      'open': (openSize, TargetPlatform.iOS),
      'desktop': (openSize, TargetPlatform.macOS),
    };
    final actions = {'cancel': cancelEntry, 'save': saveEntry};

    for (final mode in modes.entries) {
      for (final action in actions.entries) {
        testWidgets('${mode.key} ${action.key} keeps the destination', (
          tester,
        ) async {
          final (size, platform) = mode.value;
          final harness = await pumpShell(
            tester,
            size: size,
            platform: platform,
          );
          harness.container.read(selectedDestinationProvider.notifier).state =
              ShellDestination.trends;
          await tester.pumpAndSettle();
          await openAdd(tester, harness);
          expect(harness.recorder.sheets, hasLength(1));

          await action.value(tester, harness);
          await harness.opened;

          expect(harness.recorder.sheets, isEmpty);
          expect(harness.presentation, NewEntryPresentation.closed);
          expect(
            harness.container.read(selectedDestinationProvider),
            ShellDestination.trends,
          );
        });
      }
    }
  });

  group('dismissal beneath a covering route', () {
    testWidgets('removes only Add and discards the picker result', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      final unrelated = MaterialPageRoute<void>(
        builder: (_) => const Text('unrelated'),
      );
      unawaited(
        Navigator.of(harness.context, rootNavigator: true).push(unrelated),
      );
      await tester.pumpAndSettle();
      await openAdd(tester, harness);
      harness.form.requestPickSource();
      await tester.pumpAndSettle();
      final picker = harness.recorder.routes.last;
      expect(pickerCount(), 1);
      final before = harness.draft;

      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;

      expect(harness.recorder.sheets, isEmpty);
      expect(pickerCount(), 1);
      expect(unrelated.isActive, isTrue);
      final navigator = picker.navigator!;
      navigator.removeRoute(picker, const PickerChose(checkingId));
      await tester.pumpAndSettle();
      expect(harness.draft, before);
      expect(unrelated.isActive, isTrue);
    });

    testWidgets('repeated dismissal and route end retire once', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final dismiss = addDismiss(tester);
      final navigator = harness.recorder.sheets.single.navigator!;
      final removalsBefore = harness.recorder.removals;

      dismiss();
      dismiss();
      dismiss();
      navigator.maybePop();
      await tester.pumpAndSettle();
      dismiss();
      await harness.opened;

      expect(harness.recorder.removals, removalsBefore + 1);
      expect(harness.presentation, NewEntryPresentation.closed);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the open page keeps its left half until the route completes', (
    tester,
  ) async {
    final harness = await pumpShell(tester, size: openSize);
    final overview = find.text(probeLabel);
    final fullPageX = tester.getCenter(overview).dx;
    await openAdd(tester, harness);
    final halfX = tester.getCenter(overview).dx;
    var settled = false;
    unawaited(harness.opened.then((_) => settled = true));

    harness.recorder.sheets.single.navigator!.pop();
    await tester.pump();
    await tester.pump(halfTransition);

    expect(harness.presentation, NewEntryPresentation.presented);
    expect(tester.getCenter(overview).dx, halfX);
    expect(settled, isFalse);
    var duplicateSettled = false;
    unawaited(harness.open().then((_) => duplicateSettled = true));
    await tester.pump();
    expect(duplicateSettled, isTrue);
    expect(harness.recorder.sheetPushes, 1);

    await tester.pumpAndSettle();

    expect(harness.presentation, NewEntryPresentation.closed);
    expect(settled, isTrue);
    expect(tester.getCenter(overview).dx, fullPageX);
    expect(halfX, lessThan(fullPageX));
    await openAdd(tester, harness);
    expect(harness.recorder.sheetPushes, 2);
    addDismiss(tester)();
    await tester.pumpAndSettle();
    await harness.opened;
  });

  group('session-owned Step consumption', () {
    testWidgets('a Step emitted before the first mounted frame is picked up '
        'once', (tester) async {
      final harness = await pumpShell(tester);
      harness.opened = harness.open();
      await tester.idle();
      expect(harness.presentation, NewEntryPresentation.presented);
      expect(find.byType(EntryForm), findsNothing);
      final form = harness.form;
      final clearsBefore = form.clears;

      form.requestPickSource();
      expect(pickerCount(), 0);
      await tester.pumpAndSettle();

      expect(pickerCount(), 1);
      expect(form.clears, clearsBefore + 1);
      expect(harness.recorder.sheets, hasLength(1));
      harness.recorder.routes.last.navigator!.pop();
      await tester.pumpAndSettle();
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('a replacement emitted during dispatch keeps its own '
        'consumption', (tester) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final form = harness.form;
      final clearsBefore = form.clears;
      harness.ledger.onNextRead = form.requestPickDate;

      form.requestPickSource();
      await tester.pumpAndSettle();

      expect(form.clears, clearsBefore + 2);
      expect(pickerCount(), 1);
      expect(find.byType(DatePickerSheet), findsOneWidget);
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('the same request repeated after its clear stays valid', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final form = harness.form;
      final clearsBefore = form.clears;

      for (var i = 0; i < 2; i++) {
        form.requestPickSource();
        await tester.pumpAndSettle();
        expect(pickerCount(), 1);
        harness.recorder.routes.last.navigator!.pop();
        await tester.pumpAndSettle();
      }

      expect(form.clears, clearsBefore + 2);
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('resizing keeps the session, routes, draft and a picker', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final addRoute = harness.recorder.sheets.single;
      harness.form.setName('Keep');
      harness.form.requestPickSource();
      await tester.pumpAndSettle();
      final picker = harness.recorder.routes.last;
      final draft = harness.draft;
      final clears = harness.form.clears;

      for (final size in [openSize, phoneSize, openSize]) {
        await resize(tester, size);
      }

      expect(harness.recorder.sheets.single, same(addRoute));
      expect(harness.recorder.routes.last, same(picker));
      expect(harness.draft, draft);
      expect(harness.form.clears, clears);
      expect(pickerCount(), 1);
      picker.navigator!.pop();
      await tester.pumpAndSettle();
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
    });

    testWidgets('a retired subscription neither pushes nor clears', (
      tester,
    ) async {
      final harness = await pumpShell(tester);
      await openAdd(tester, harness);
      final form = harness.form;
      addDismiss(tester)();
      await tester.pumpAndSettle();
      await harness.opened;
      final clears = form.clears;
      final routes = harness.recorder.routes.length;

      form.requestPickSource();
      await tester.pumpAndSettle();

      expect(form.clears, clears);
      expect(harness.recorder.routes, hasLength(routes));
    });
  });

  group('results arriving after close and reopen are discarded', () {
    final markerDate = DateTime.utc(2026, 3, 4);
    final results = <String, (void Function(CountingForm, Uint8List), Object?)>{
      'source': (
        (f, _) => f.requestPickSource(),
        const PickerChose(_staleSourceId),
      ),
      'destination': (
        (f, _) => f.requestPickDestination(),
        const PickerChose(checkingId),
      ),
      'category': (
        (f, _) => f.requestPickCategory(),
        const PickerChose(_staleCategoryId),
      ),
      'recurrence': ((f, _) => f.requestPickRecurrence(), null),
      'date': ((f, _) => f.requestPickDate(), DateTime.utc(2026, 1, 2)),
      'end date': ((f, _) => f.requestPickEndDate(), DateTime.utc(2026, 1, 2)),
      'crop': ((f, png) => f.requestDocumentCrop(png), Uint8List.fromList([1])),
    };

    void markFreshDraft(CountingForm form) {
      form.applyPickedSource(checkingId);
      form.applyPickedCategory(coffeeId);
      form.applyPickedRecurrence(RecurrenceFrequency.weekly);
      form.applyPickedDate(markerDate);
      form.setEndDateEnabled(true);
      form.applyPickedEndDate(markerDate);
    }

    for (final entry in results.entries) {
      testWidgets('${entry.key} result', (tester) async {
        final (request, result) = entry.value;
        final harness = await pumpShell(tester);
        await openAdd(tester, harness);
        final png = await tester.runAsync(solidPng);
        request(harness.form, png!);
        await tester.pump();
        await tester.pump(halfTransition);
        await tester.runAsync(() => Future<void>.delayed(decodeWait));
        await tester.pump(halfTransition);
        final covering = harness.recorder.routes.last;
        addDismiss(tester)();
        await tester.pumpAndSettle();
        await harness.opened;
        await openAdd(tester, harness);
        markFreshDraft(harness.form);
        await tester.pumpAndSettle();
        final fresh = harness.draft;
        var scanEvents = 0;
        harness.container.listen(
          receiptEntryCoordinatorProvider(null),
          (_, _) => scanEvents++,
        );

        covering.navigator!.removeRoute(covering, result);
        await tester.pumpAndSettle();

        expect(harness.draft, fresh);
        expect(scanEvents, 0);
        addDismiss(tester)();
        await tester.pumpAndSettle();
        await harness.opened;
      });
    }
  });
}
