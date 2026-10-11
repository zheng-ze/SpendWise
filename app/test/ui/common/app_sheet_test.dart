import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/ui/common/app_sheet.dart';
import 'package:spendwise/ui/common/sheet_alert.dart';

import '../../support/sheet_contract.dart' as contract;

const _phone = Size(320, 760);
const _compact = Size(320, 560);
const _probeHeight = 760.0;
const _probeWidths = [320.0, 719.0, 720.0, 1200.0];
const _sheetMaxWidth = 440.0;

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

Future<void> _openSheet(
  WidgetTester tester,
  AppSheet sheet, {
  AppSheetPresentation presentation = AppSheetPresentation.phone,
}) async {
  final app = MaterialApp(
    home: _SheetLauncher(
      sheet: sheet,
      label: 'open',
      presentation: presentation,
    ),
  );
  await tester.pumpWidget(app);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher({
    required this.sheet,
    required this.label,
    required this.presentation,
  });

  final AppSheet sheet;

  final String label;

  final AppSheetPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showAppSheet<void>(
        context,
        presentation: presentation,
        builder: (_) => sheet,
      ),
      child: Text(label),
    );
  }
}

class _LayerButton extends StatelessWidget {
  const _LayerButton({required this.presentation});

  final AppSheetPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showAppSheet<void>(
        context,
        presentation: presentation,
        builder: (_) =>
            const AppSheet(header: Text('second'), body: Text('second body')),
      ),
      child: const Text('layer'),
    );
  }
}

Widget _layeredSheetApp({required AppSheetPresentation presentation}) {
  return MaterialApp(
    home: _SheetLauncher(
      label: 'open',
      presentation: presentation,
      sheet: AppSheet(
        header: const Text('first'),
        body: _LayerButton(presentation: presentation),
      ),
    ),
  );
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

  for (final width in _probeWidths) {
    testWidgets('phone presentation at ${width.toInt()}px spans the full width '
        'at the bottom', (tester) async {
      _useSize(tester, Size(width, _probeHeight));
      await _openSheet(
        tester,
        _sheet(body: const Text('short body')),
        presentation: AppSheetPresentation.phone,
      );

      final rect = tester.getRect(find.byType(AppSheet));
      expect(rect.left, 0);
      expect(rect.right, width);
      expect(rect.bottom, _probeHeight);
    });

    testWidgets('desktop presentation at ${width.toInt()}px centres a dialog '
        'no wider than 440', (tester) async {
      _useSize(tester, Size(width, _probeHeight));
      await _openSheet(
        tester,
        _sheet(body: const Text('short body')),
        presentation: AppSheetPresentation.desktop,
      );

      final rect = tester.getRect(find.byType(AppSheet));
      expect(rect.center, Offset(width / 2, _probeHeight / 2));
      expect(rect.width, lessThanOrEqualTo(_sheetMaxWidth));
      expect(rect.width, lessThanOrEqualTo(width));
    });
  }

  testWidgets('resizing keeps the captured phone presentation', (tester) async {
    _useSize(tester, const Size(320, _probeHeight));
    await _openSheet(
      tester,
      _sheet(
        alert: const SheetAlertData(
          message: 'Could not save entry.',
          severity: SheetAlertSeverity.error,
        ),
        body: const Text('short body'),
      ),
      presentation: AppSheetPresentation.phone,
    );

    tester.view.physicalSize = const Size(1200, _probeHeight);
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(AppSheet));
    expect(rect.left, 0);
    expect(rect.right, 1200);
    expect(rect.bottom, _probeHeight);
    expect(find.text('Could not save entry.'), findsOneWidget);

    await tester.tapAt(const Offset(600, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
  });

  testWidgets('resizing keeps the captured desktop presentation', (
    tester,
  ) async {
    _useSize(tester, const Size(1200, _probeHeight));
    await _openSheet(
      tester,
      _sheet(
        alert: const SheetAlertData(
          message: 'Sync timed out.',
          severity: SheetAlertSeverity.warning,
        ),
        body: const Text('short body'),
      ),
      presentation: AppSheetPresentation.desktop,
    );

    tester.view.physicalSize = const Size(320, _probeHeight);
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(AppSheet));
    expect(rect.center, const Offset(160, _probeHeight / 2));
    expect(rect.width, lessThanOrEqualTo(_sheetMaxWidth));
    expect(find.text('Sync timed out.'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheet), findsNothing);
  });

  testWidgets(
    'an AppSheet without its presentation slot reports a caller error',
    (tester) async {
      _useSize(tester, _phone);
      await tester.pumpWidget(
        MaterialApp(home: _sheet(body: const Text('short body'))),
      );

      expect(tester.takeException(), isFlutterError);
    },
  );

  testWidgets('a directly pushed route carries its captured presentation', (
    tester,
  ) async {
    _useSize(tester, _phone);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              AppSheetRoute<void>(
                presentation: AppSheetPresentation.desktop,
                builder: (_) => _sheet(body: const Text('direct body')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(AppSheet));
    expect(rect.center, Offset(_phone.width / 2, _phone.height / 2));
    expect(rect.width, lessThanOrEqualTo(_sheetMaxWidth));
  });

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
    Future<void> openFromNested(
      WidgetTester tester,
      Size size,
      AppSheetPresentation presentation,
    ) async {
      _useSize(tester, size);
      final app = MaterialApp(
        home: _NestedSheetHost(presentation: presentation),
      );
      await tester.pumpWidget(app);
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
      await openFromNested(tester, _phone, AppSheetPresentation.phone);

      expect(tester.getRect(find.byType(AppSheet)).width, _phone.width);
      expect(barrierCovers(tester, _phone), isTrue);
    });

    testWidgets('the desktop dialog centres in the window, not the pane', (
      tester,
    ) async {
      const desktop = Size(1200, 800);
      await openFromNested(tester, desktop, AppSheetPresentation.desktop);

      expect(
        tester.getRect(find.byType(AppSheet)).center,
        Offset(desktop.width / 2, desktop.height / 2),
      );
      expect(barrierCovers(tester, desktop), isTrue);
    });
  });

  testWidgets('the contract helper checks every drawn sheet', (tester) async {
    contract.useSheetSize(tester, _phone);
    await tester.pumpWidget(
      _layeredSheetApp(presentation: AppSheetPresentation.phone),
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

        final rowScroller = find
            .ancestor(
              of: find.text('row 0'),
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        await tester.fling(rowScroller, const Offset(0, -500), 2000);
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
      final outerScrollable = find
          .descendant(
            of: find.byType(AppSheet),
            matching: find.byType(Scrollable),
          )
          .first;

      await tester.scrollUntilVisible(
        find.text('key 0'),
        100,
        scrollable: outerScrollable,
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
      _layeredSheetApp(presentation: AppSheetPresentation.phone),
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

    Future<void> openWatchedSheet(
      WidgetTester tester, {
      AppSheetPresentation presentation = AppSheetPresentation.phone,
    }) async {
      final app = ProviderScope(
        child: MaterialApp(
          home: _WatchedSheetLauncher(
            provider: alertProvider,
            presentation: presentation,
          ),
        ),
      );
      await tester.pumpWidget(app);
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

      contract.expectAlertOutsideSheet(tester);
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
      _useSize(tester, const Size(1200, 800));
      await _openSheet(
        tester,
        _sheet(body: const Text('short body')),
        presentation: AppSheetPresentation.desktop,
      );

      final width = tester.getSize(find.byType(AppSheet)).width;
      expect(width, lessThanOrEqualTo(440));
    });

    testWidgets('the alert sits outside the dialog and changes no height', (
      tester,
    ) async {
      _useSize(tester, const Size(1200, 800));
      final app = ProviderScope(
        child: MaterialApp(
          home: _WatchedSheetLauncher(
            provider: alertProvider,
            presentation: AppSheetPresentation.desktop,
          ),
        ),
      );
      await tester.pumpWidget(app);
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

      contract.expectAlertOutsideSheet(tester);
      expect(_sheetHeight(tester), before);
    });
  });
}

class _NestedSheetHost extends StatelessWidget {
  const _NestedSheetHost({required this.presentation});

  final AppSheetPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    presentation: presentation,
                    builder: (_) => _sheet(body: const Text('nested body')),
                  ),
                  child: const Text('open nested'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchedSheetLauncher extends StatelessWidget {
  const _WatchedSheetLauncher({
    required this.provider,
    required this.presentation,
  });

  final StateProvider<SheetAlertData?> provider;

  final AppSheetPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showAppSheet<void>(
        context,
        presentation: presentation,
        builder: (_) => _WatchedSheet(provider: provider),
      ),
      child: const Text('open'),
    );
  }
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
