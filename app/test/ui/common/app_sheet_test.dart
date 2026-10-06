import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/app_sheet.dart';
import 'package:spendwise/ui/common/sheet_alert.dart';

import '../../support/sheet_contract.dart' as contract;

const _phone = Size(320, 760);
const _compact = Size(320, 560);
const _desktop = Size(1200, 800);

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

AppSheet _sheet({
  SheetAlertData? alert,
  Widget? footer,
  Widget? inputSurface,
  required Widget body,
}) {
  return AppSheet(
    header: const Text('Sheet title'),
    body: body,
    footer: footer,
    inputSurface: inputSurface,
    alert: alert,
  );
}

Future<void> _openSheet(WidgetTester tester, AppSheet sheet) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppSheet<void>(context, builder: (_) => sheet),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

double _sheetHeight(WidgetTester tester) =>
    tester.getSize(find.byType(AppSheet)).height;

void main() {
  testWidgets('short content sizes below the two-thirds cap', (tester) async {
    _useSize(tester, _phone);
    await _openSheet(tester, _sheet(body: const Text('short body')));

    expect(_sheetHeight(tester), lessThan(0.66 * _phone.height));
  });

  testWidgets('short content leaves no gap between body and footer', (
    tester,
  ) async {
    _useSize(tester, _phone);
    await _openSheet(
      tester,
      _sheet(footer: const Text('Save'), body: const Text('short body')),
    );

    final bodyRect = tester.getRect(find.text('short body'));
    final footerRect = tester.getRect(find.text('Save'));
    expect(footerRect.top, bodyRect.bottom);
  });

  for (final size in [_phone, _compact]) {
    testWidgets(
      'phone sheets span the full width at ${size.height.toInt()}px',
      (tester) async {
        _useSize(tester, size);
        await _openSheet(tester, _sheet(body: const Text('short body')));

        final rect = tester.getRect(find.byType(AppSheet));
        expect(rect.left, 0);
        expect(rect.right, size.width);
      },
    );
  }

  testWidgets('footer and input surface stay above the bottom safe inset', (
    tester,
  ) async {
    _useSize(tester, _phone);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    await _openSheet(
      tester,
      _sheet(
        footer: const Text('Save'),
        inputSurface: const Text('number pad'),
        body: const Text('short body'),
      ),
    );

    expect(
      tester.getRect(find.text('Save')).bottom,
      lessThanOrEqualTo(_phone.height - 34),
    );
    expect(
      tester.getRect(find.text('number pad')).bottom,
      lessThanOrEqualTo(_phone.height - 34),
    );
    expect(find.text('Save').hitTestable(), findsOneWidget);
    expect(find.text('number pad').hitTestable(), findsOneWidget);
    final background = tester.getRect(
      find
          .descendant(
            of: find.byType(AppSheet),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(background.bottom, _phone.height);
  });

  group('root navigator', () {
    Future<void> openFromNested(WidgetTester tester, Size size) async {
      _useSize(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('outer'),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (context) => TextButton(
                        onPressed: () => showAppSheet<void>(
                          context,
                          builder: (_) =>
                              _sheet(body: const Text('nested body')),
                        ),
                        child: const Text('open nested'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('open nested'));
      await tester.pumpAndSettle();
    }

    bool barrierCovers(WidgetTester tester, Size window) {
      for (final element in find.byType(ModalBarrier).evaluate()) {
        final box = element.renderObject;
        if (box is! RenderBox || !box.hasSize) continue;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect == Offset.zero & window) return true;
      }
      return false;
    }

    testWidgets('the barrier and sheet cover the window, not the pane', (
      tester,
    ) async {
      await openFromNested(tester, _phone);

      expect(tester.getRect(find.byType(AppSheet)).width, _phone.width);
      expect(barrierCovers(tester, _phone), isTrue);
    });

    testWidgets('the desktop dialog centres in the window, not the pane', (
      tester,
    ) async {
      await openFromNested(tester, _desktop);

      expect(
        tester.getRect(find.byType(AppSheet)).center,
        Offset(_desktop.width / 2, _desktop.height / 2),
      );
      expect(barrierCovers(tester, _desktop), isTrue);
    });
  });

  testWidgets('the contract helper checks every drawn sheet', (tester) async {
    contract.useSheetSize(tester, _phone);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context,
              builder: (_) => AppSheet(
                header: const Text('first'),
                body: Builder(
                  builder: (sheetContext) => TextButton(
                    onPressed: () => showAppSheet<void>(
                      sheetContext,
                      builder: (_) => const AppSheet(
                        header: Text('second'),
                        body: Text('second body'),
                      ),
                    ),
                    child: const Text('layer'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('layer'));
    await tester.pumpAndSettle();

    contract.expectAllSheetsCapped(tester, _phone);
    expect(contract.appSheetHeight(tester, 0), greaterThan(0));
    expect(contract.appSheetHeight(tester, 1), greaterThan(0));
  });

  for (final size in [_phone, _compact]) {
    testWidgets(
      'long content at ${size.height.toInt()}px stops at the cap and scrolls',
      (tester) async {
        _useSize(tester, size);
        await _openSheet(
          tester,
          _sheet(
            footer: const Text('Save'),
            inputSurface: const Text('number pad'),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (var i = 0; i < 40; i++) Text('row $i')],
            ),
          ),
        );

        final cap = 0.66 * size.height;
        expect(_sheetHeight(tester), lessThanOrEqualTo(cap + 1));

        expect(find.text('Sheet title').hitTestable(), findsOneWidget);
        expect(find.text('Save').hitTestable(), findsOneWidget);
        expect(find.text('number pad').hitTestable(), findsOneWidget);

        await tester.fling(
          find
              .ancestor(
                of: find.text('row 0'),
                matching: find.byType(SingleChildScrollView),
              )
              .first,
          const Offset(0, -500),
          2000,
        );
        await tester.pumpAndSettle();

        expect(find.text('Sheet title').hitTestable(), findsOneWidget);
        expect(find.text('Save').hitTestable(), findsOneWidget);
        expect(find.text('number pad').hitTestable(), findsOneWidget);
        expect(find.text('row 39').hitTestable(), findsOneWidget);
        expect(_sheetHeight(tester), lessThanOrEqualTo(cap + 1));
      },
    );
  }

  testWidgets('with keyboard insets the footer stays visible', (tester) async {
    _useSize(tester, _phone);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await _openSheet(
      tester,
      _sheet(
        footer: const Text('Save'),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < 40; i++) Text('row $i')],
        ),
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(
      tester.getRect(find.text('Save')).bottom,
      lessThanOrEqualTo(_phone.height - 300 + 1),
    );
  });

  for (final (label, size, keyboard) in [
    ('a landscape phone', const Size(640, 360), 0.0),
    ('a compact phone with the keyboard up', _compact, 260.0),
  ]) {
    testWidgets('on $label oversized pinned parts scroll into reach', (
      tester,
    ) async {
      _useSize(tester, size);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      var saved = false;
      var keyPressed = false;
      await _openSheet(
        tester,
        _sheet(
          footer: TextButton(
            onPressed: () => saved = true,
            child: const Text('Save'),
          ),
          inputSurface: SizedBox(
            height: 220,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TextButton(
                onPressed: () => keyPressed = true,
                child: const Text('key 0'),
              ),
            ),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (var i = 0; i < 10; i++) Text('row $i')],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final cap = 0.66 * (size.height - keyboard);
      expect(_sheetHeight(tester), lessThanOrEqualTo(cap + 1));

      await tester.scrollUntilVisible(
        find.text('key 0'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(AppSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('key 0'));
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));

      expect(keyPressed, isTrue);
      expect(saved, isTrue);
    });
  }

  testWidgets('layered sheets push a second route', (tester) async {
    _useSize(tester, _phone);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context,
              builder: (_) => AppSheet(
                header: const Text('first'),
                body: Builder(
                  builder: (sheetContext) => TextButton(
                    onPressed: () => showAppSheet<void>(
                      sheetContext,
                      builder: (_) => const AppSheet(
                        header: Text('second'),
                        body: Text('second body'),
                      ),
                    ),
                    child: const Text('layer'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    await tester.tap(find.text('layer'));
    await tester.pumpAndSettle();
    expect(find.text('second body'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
  });

  group('sheet alert slot', () {
    final alertProvider = StateProvider<SheetAlertData?>((ref) => null);

    Future<void> openWatchedSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (_) => _WatchedSheet(provider: alertProvider),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.text('Sheet title')));

    testWidgets('setting an alert leaves the sheet height unchanged', (
      tester,
    ) async {
      _useSize(tester, _phone);
      await openWatchedSheet(tester);
      final before = _sheetHeight(tester);

      containerOf(tester)
          .read(alertProvider.notifier)
          .state = const SheetAlertData(
        message: 'Could not save entry.',
        severity: SheetAlertSeverity.error,
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not save entry.'), findsOneWidget);
      expect(_sheetHeight(tester), before);
    });

    testWidgets('the banner renders outside the sheet subtree', (tester) async {
      _useSize(tester, _phone);
      await openWatchedSheet(tester);
      containerOf(tester)
          .read(alertProvider.notifier)
          .state = const SheetAlertData(
        message: 'Could not save entry.',
        severity: SheetAlertSeverity.error,
      );
      await tester.pumpAndSettle();

      expect(find.byType(SheetAlert), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(SheetAlert),
          matching: find.byType(AppSheet),
        ),
        findsNothing,
      );
    });

    testWidgets('clearing the alert removes the banner', (tester) async {
      _useSize(tester, _phone);
      await openWatchedSheet(tester);
      final container = containerOf(tester);
      container.read(alertProvider.notifier).state = const SheetAlertData(
        message: 'Could not save entry.',
        severity: SheetAlertSeverity.warning,
      );
      await tester.pumpAndSettle();
      expect(find.byType(SheetAlert), findsOneWidget);

      container.read(alertProvider.notifier).state = null;
      await tester.pumpAndSettle();
      expect(find.byType(SheetAlert), findsNothing);
    });
  });

  group('desktop layout', () {
    final alertProvider = StateProvider<SheetAlertData?>((ref) => null);

    testWidgets('the sheet becomes a dialog no wider than 440', (tester) async {
      _useSize(tester, _desktop);
      await _openSheet(tester, _sheet(body: const Text('short body')));

      final width = tester.getSize(find.byType(AppSheet)).width;
      expect(width, lessThanOrEqualTo(440));
    });

    testWidgets('the alert sits outside the dialog and changes no height', (
      tester,
    ) async {
      _useSize(tester, _desktop);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSheet<void>(
                  context,
                  builder: (_) => _WatchedSheet(provider: alertProvider),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final before = _sheetHeight(tester);

      ProviderScope.containerOf(tester.element(find.text('Sheet title')))
          .read(alertProvider.notifier)
          .state = const SheetAlertData(
        message: 'Sync timed out.',
        severity: SheetAlertSeverity.warning,
      );
      await tester.pumpAndSettle();

      expect(find.byType(SheetAlert), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(SheetAlert),
          matching: find.byType(AppSheet),
        ),
        findsNothing,
      );
      expect(_sheetHeight(tester), before);
    });
  });
}

class _WatchedSheet extends ConsumerWidget {
  const _WatchedSheet({required this.provider});

  final StateProvider<SheetAlertData?> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppSheet(
      header: const Text('Sheet title'),
      body: const Text('sheet body'),
      footer: const Text('Save'),
      alert: ref.watch(provider),
    );
  }
}
