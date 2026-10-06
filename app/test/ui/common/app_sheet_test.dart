import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/app_sheet.dart';
import 'package:spendwise/ui/common/sheet_alert.dart';

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

        expect(find.text('Sheet title'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('number pad'), findsOneWidget);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sheet title'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('number pad'), findsOneWidget);
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
