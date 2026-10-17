import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/sync/hosted_sync_status.dart';
import 'package:spendwise/ui/shell/app_shell.dart';
import 'package:spendwise/ui/shell/shell_binding.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

import '../../support/ui_test_timeout.dart';

const _openSize = Size(960, 720);
const _compactSize = Size(320, 760);
const _landscapePhoneSize = Size(800, 400);
const _narrowTabletSize = Size(400, 800);

ShellPlatformFacts _facts(TargetPlatform platform, {bool isWeb = false}) =>
    (isWeb: isWeb, targetPlatform: platform);

void _setLogicalSize(
  WidgetTester tester,
  Size logical, {
  double devicePixelRatio = 1,
}) {
  tester.view.physicalSize = Size(
    logical.width * devicePixelRatio,
    logical.height * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
}

class _ModeProbe extends ConsumerWidget {
  const _ModeProbe({this.onBuilt});

  final void Function(BuildContext context, WidgetRef ref)? onBuilt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuilt?.call(context, ref);
    final scopeMode = ShellLayoutModeScope.of(context);
    final providerMode = ref.watch(shellLayoutModeProvider);
    return Text(
      'scope $scopeMode provider $providerMode',
      textDirection: TextDirection.ltr,
    );
  }
}

Future<void> _pumpBound(
  WidgetTester tester, {
  required ShellPlatformFacts platform,
  required Size logicalSize,
  double devicePixelRatio = 1,
  ShellLayoutMode? modeOverride,
}) async {
  _setLogicalSize(tester, logicalSize, devicePixelRatio: devicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
        shellPlatformProvider.overrideWithValue(platform),
        if (modeOverride != null)
          shellLayoutModeProvider.overrideWithValue(modeOverride),
      ],
      child: MaterialApp(
        builder: buildShellAppContent,
        home: const _ModeProbe(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ShellLayoutMode _probedMode(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(_ModeProbe)))
        .read(shellLayoutModeProvider);

ShellLayoutMode _scopeMode(WidgetTester tester) =>
    ShellLayoutModeScope.of(tester.element(find.byType(_ModeProbe)));

Future<void> _resize(WidgetTester tester, Size logicalSize) async {
  _setLogicalSize(tester, logicalSize);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('resolveShellLayoutMode', () {
    test('iOS and Android at 960 x 720 resolve to open', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(
          resolveShellLayoutMode(
            isWeb: false,
            targetPlatform: platform,
            windowSize: _openSize,
          ),
          ShellLayoutMode.open,
        );
      }
    });

    test('iOS and Android below either threshold resolve to phone', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final size in [
          _compactSize,
          _landscapePhoneSize,
          _narrowTabletSize,
          const Size(599, 480),
          const Size(600, 479),
          const Size(599, 479),
          const Size(599, 720),
          const Size(960, 479),
        ]) {
          expect(
            resolveShellLayoutMode(
              isWeb: false,
              targetPlatform: platform,
              windowSize: size,
            ),
            ShellLayoutMode.phone,
            reason: '$platform at $size',
          );
        }
      }
    });

    test('the inclusive 600 x 480 boundary resolves to open', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final size in [
          const Size(600, 480),
          const Size(600, 481),
          const Size(601, 480),
        ]) {
          expect(
            resolveShellLayoutMode(
              isWeb: false,
              targetPlatform: platform,
              windowSize: size,
            ),
            ShellLayoutMode.open,
            reason: '$platform at $size',
          );
        }
      }
    });

    test('macOS, Windows, Linux and Fuchsia resolve to desktop', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        for (final size in [_openSize, _compactSize, Size.zero]) {
          expect(
            resolveShellLayoutMode(
              isWeb: false,
              targetPlatform: platform,
              windowSize: size,
            ),
            ShellLayoutMode.desktop,
            reason: '$platform at $size',
          );
        }
      }
    });

    test('web resolves to desktop regardless of target platform', () {
      for (final platform in TargetPlatform.values) {
        for (final size in [_openSize, _compactSize, Size.zero]) {
          expect(
            resolveShellLayoutMode(
              isWeb: true,
              targetPlatform: platform,
              windowSize: size,
            ),
            ShellLayoutMode.desktop,
            reason: '$platform at $size',
          );
        }
      }
    });

    test('Size.zero defaults mobile to phone and desktop to desktop', () {
      expect(
        resolveShellLayoutMode(
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
          windowSize: Size.zero,
        ),
        ShellLayoutMode.phone,
      );
      expect(
        resolveShellLayoutMode(
          isWeb: false,
          targetPlatform: TargetPlatform.android,
          windowSize: Size.zero,
        ),
        ShellLayoutMode.phone,
      );
      expect(
        resolveShellLayoutMode(
          isWeb: false,
          targetPlatform: TargetPlatform.macOS,
          windowSize: Size.zero,
        ),
        ShellLayoutMode.desktop,
      );
      expect(
        resolveShellLayoutMode(
          isWeb: true,
          targetPlatform: TargetPlatform.iOS,
          windowSize: Size.zero,
        ),
        ShellLayoutMode.desktop,
      );
    });
  });

  group('unbound provider defaults', () {
    test('Size.zero defaults mobile to phone and desktop to desktop', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        final container = ProviderContainer(
          overrides: [
            shellPlatformProvider.overrideWithValue(_facts(platform)),
          ],
        );
        addTearDown(container.dispose);
        expect(container.read(shellLayoutModeProvider), ShellLayoutMode.phone);
      }
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        final container = ProviderContainer(
          overrides: [
            shellPlatformProvider.overrideWithValue(_facts(platform)),
          ],
        );
        addTearDown(container.dispose);
        expect(
          container.read(shellLayoutModeProvider),
          ShellLayoutMode.desktop,
        );
      }
      final webContainer = ProviderContainer(
        overrides: [
          shellPlatformProvider.overrideWithValue(
            _facts(TargetPlatform.iOS, isWeb: true),
          ),
        ],
      );
      addTearDown(webContainer.dispose);
      expect(
        webContainer.read(shellLayoutModeProvider),
        ShellLayoutMode.desktop,
      );
    });

    test('an explicit unbound window-size override feeds the resolver', () {
      final container = ProviderContainer(
        overrides: [
          shellPlatformProvider.overrideWithValue(_facts(TargetPlatform.iOS)),
          shellWindowSizeProvider.overrideWithValue(_openSize),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(shellLayoutModeProvider), ShellLayoutMode.open);
    });

    test('platform classification is fixed for the container lifetime', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(shellLayoutModeProvider), ShellLayoutMode.phone);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(container.read(shellLayoutModeProvider), ShellLayoutMode.phone);
    });
  });

  group('bound window sizes', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('$platform 960 x 720 renders open', (tester) async {
        _setLogicalSize(tester, _openSize);
        addTearDown(tester.view.reset);
        await _pumpBound(
          tester,
          platform: _facts(platform),
          logicalSize: _openSize,
        );

        expect(_probedMode(tester), ShellLayoutMode.open);
        expect(_scopeMode(tester), ShellLayoutMode.open);
      }, timeout: uiTestTimeout);

      testWidgets('$platform phone sizes render phone', (tester) async {
        for (final size in [
          _compactSize,
          _landscapePhoneSize,
          _narrowTabletSize,
        ]) {
          _setLogicalSize(tester, size);
          addTearDown(tester.view.reset);
          await _pumpBound(
            tester,
            platform: _facts(platform),
            logicalSize: size,
          );
          expect(
            _probedMode(tester),
            ShellLayoutMode.phone,
            reason: '$platform at $size',
          );
          addTearDown(tester.view.reset);
        }
      }, timeout: uiTestTimeout);

      testWidgets('$platform threshold boundaries resolve inclusively', (
        tester,
      ) async {
        final cases = {
          const Size(600, 480): ShellLayoutMode.open,
          const Size(599, 480): ShellLayoutMode.phone,
          const Size(600, 479): ShellLayoutMode.phone,
          const Size(599, 479): ShellLayoutMode.phone,
          const Size(600, 720): ShellLayoutMode.open,
          const Size(599, 720): ShellLayoutMode.phone,
          const Size(960, 480): ShellLayoutMode.open,
          const Size(960, 479): ShellLayoutMode.phone,
        };
        for (final entry in cases.entries) {
          _setLogicalSize(tester, entry.key);
          addTearDown(tester.view.reset);
          await _pumpBound(
            tester,
            platform: _facts(platform),
            logicalSize: entry.key,
          );
          expect(
            _probedMode(tester),
            entry.value,
            reason: '$platform at ${entry.key}',
          );
          addTearDown(tester.view.reset);
        }
      }, timeout: uiTestTimeout);

      testWidgets('$platform runtime resize follows the window', (
        tester,
      ) async {
        _setLogicalSize(tester, _openSize);
        addTearDown(tester.view.reset);
        await _pumpBound(
          tester,
          platform: _facts(platform),
          logicalSize: _openSize,
        );
        expect(_probedMode(tester), ShellLayoutMode.open);

        await _resize(tester, _compactSize);
        expect(_probedMode(tester), ShellLayoutMode.phone);

        await _resize(tester, _openSize);
        expect(_probedMode(tester), ShellLayoutMode.open);
      }, timeout: uiTestTimeout);
    }

    testWidgets('logical sizing holds at a non-1 device-pixel ratio', (
      tester,
    ) async {
      _setLogicalSize(tester, _openSize, devicePixelRatio: 2.5);
      addTearDown(tester.view.reset);
      await _pumpBound(
        tester,
        platform: _facts(TargetPlatform.iOS),
        logicalSize: _openSize,
        devicePixelRatio: 2.5,
      );

      expect(_probedMode(tester), ShellLayoutMode.open);
    }, timeout: uiTestTimeout);

    testWidgets('keyboard insets do not change the mode', (tester) async {
      _setLogicalSize(tester, _openSize);
      addTearDown(tester.view.reset);
      await _pumpBound(
        tester,
        platform: _facts(TargetPlatform.iOS),
        logicalSize: _openSize,
      );
      expect(_probedMode(tester), ShellLayoutMode.open);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(_probedMode(tester), ShellLayoutMode.open);
    }, timeout: uiTestTimeout);

    testWidgets('injected display features do not change the mode', (
      tester,
    ) async {
      _setLogicalSize(tester, _openSize);
      addTearDown(tester.view.reset);
      await _pumpBound(
        tester,
        platform: _facts(TargetPlatform.android),
        logicalSize: _openSize,
      );
      expect(_probedMode(tester), ShellLayoutMode.open);

      tester.view.displayFeatures = [
        const ui.DisplayFeature(
          bounds: Rect.fromLTWH(0, 0, 10, 720),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.postureFlat,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);
      await tester.pumpAndSettle();

      expect(_probedMode(tester), ShellLayoutMode.open);
    }, timeout: uiTestTimeout);

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      testWidgets('$platform stays desktop across sizes and resize', (
        tester,
      ) async {
        _setLogicalSize(tester, _openSize);
        addTearDown(tester.view.reset);
        await _pumpBound(
          tester,
          platform: _facts(platform),
          logicalSize: _openSize,
        );
        expect(_probedMode(tester), ShellLayoutMode.desktop);

        await _resize(tester, _compactSize);
        expect(_probedMode(tester), ShellLayoutMode.desktop);

        await _resize(tester, _openSize);
        expect(_probedMode(tester), ShellLayoutMode.desktop);
      }, timeout: uiTestTimeout);
    }

    testWidgets('injected web stays desktop across sizes and resize', (
      tester,
    ) async {
      _setLogicalSize(tester, _openSize);
      addTearDown(tester.view.reset);
      await _pumpBound(
        tester,
        platform: _facts(TargetPlatform.iOS, isWeb: true),
        logicalSize: _openSize,
      );
      expect(_probedMode(tester), ShellLayoutMode.desktop);

      await _resize(tester, _compactSize);
      expect(_probedMode(tester), ShellLayoutMode.desktop);
    }, timeout: uiTestTimeout);

    testWidgets('Fuchsia falls back to desktop', (tester) async {
      _setLogicalSize(tester, _openSize);
      addTearDown(tester.view.reset);
      await _pumpBound(
        tester,
        platform: _facts(TargetPlatform.fuchsia),
        logicalSize: _openSize,
      );
      expect(_probedMode(tester), ShellLayoutMode.desktop);
    }, timeout: uiTestTimeout);

    testWidgets('an enclosing explicit mode override wins over geometry', (
      tester,
    ) async {
      _setLogicalSize(tester, _openSize);
      addTearDown(tester.view.reset);
      await _pumpBound(
        tester,
        platform: _facts(TargetPlatform.iOS),
        logicalSize: _openSize,
        modeOverride: ShellLayoutMode.phone,
      );
      expect(_probedMode(tester), ShellLayoutMode.phone);
      expect(_scopeMode(tester), ShellLayoutMode.phone);

      await _resize(tester, _compactSize);
      expect(_probedMode(tester), ShellLayoutMode.phone);
      expect(_scopeMode(tester), ShellLayoutMode.phone);
    }, timeout: uiTestTimeout);

    testWidgets('an enclosing explicit open override wins at phone sizes', (
      tester,
    ) async {
      _setLogicalSize(tester, _compactSize);
      addTearDown(tester.view.reset);
      await _pumpBound(
        tester,
        platform: _facts(TargetPlatform.iOS),
        logicalSize: _compactSize,
        modeOverride: ShellLayoutMode.open,
      );
      expect(_probedMode(tester), ShellLayoutMode.open);
      expect(_scopeMode(tester), ShellLayoutMode.open);
    }, timeout: uiTestTimeout);

    testWidgets('resize retains the binding container and provider identity', (
      tester,
    ) async {
      final witnessProvider = Provider<Object>((ref) => Object());
      ProviderContainer? innerBefore;
      Object? witnessBefore;
      _setLogicalSize(tester, _openSize);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
            shellPlatformProvider.overrideWithValue(_facts(TargetPlatform.iOS)),
          ],
          child: MaterialApp(
            builder: buildShellAppContent,
            home: _ModeProbe(
              onBuilt: (context, ref) {
                innerBefore ??= ProviderScope.containerOf(context);
                witnessBefore ??= ref.watch(witnessProvider);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_probedMode(tester), ShellLayoutMode.open);
      final selectedBefore = innerBefore!.read(selectedDestinationProvider);
      innerBefore!.read(selectedDestinationProvider.notifier).state =
          ShellDestination.trends;
      await tester.pumpAndSettle();

      await _resize(tester, _compactSize);
      final innerAfter = ProviderScope.containerOf(
        tester.element(find.byType(_ModeProbe)),
      );
      expect(_probedMode(tester), ShellLayoutMode.phone);
      expect(identical(innerAfter, innerBefore), isTrue);
      expect(
        identical(innerAfter.read(witnessProvider), witnessBefore),
        isTrue,
      );
      expect(
        innerAfter.read(selectedDestinationProvider),
        ShellDestination.trends,
      );
      expect(selectedBefore, ShellDestination.overview);

      await _resize(tester, _openSize);
      expect(_probedMode(tester), ShellLayoutMode.open);
      expect(
        identical(
          ProviderScope.containerOf(tester.element(find.byType(_ModeProbe))),
          innerBefore,
        ),
        isTrue,
      );
      expect(
        innerBefore!.read(selectedDestinationProvider),
        ShellDestination.trends,
      );
    }, timeout: uiTestTimeout);
  });

  group('explicit mode-override chrome fixtures', () {
    testWidgets('a provider override selects the bar on a desktop width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
            shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.phone),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );

      expect(find.byKey(const ValueKey('phone-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('sidebar')), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('a provider override selects the rail on a phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
            shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.desktop),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );

      expect(find.byKey(const ValueKey('sidebar')), findsOneWidget);
      expect(find.byKey(const ValueKey('phone-bar')), findsNothing);
    }, timeout: uiTestTimeout);

    testWidgets('an enclosing explicit open override renders the rail', (
      tester,
    ) async {
      tester.view.physicalSize = _openSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostedSyncStatusProvider.overrideWithValue(const HostedSyncReady()),
            shellLayoutModeProvider.overrideWithValue(ShellLayoutMode.open),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('open-rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('phone-bar')), findsNothing);
      expect(find.byKey(const ValueKey('sidebar')), findsNothing);
    }, timeout: uiTestTimeout);
  });
}
