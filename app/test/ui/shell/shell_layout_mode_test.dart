import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/shell/shell_providers.dart';

const _openSize = Size(600, 480);

ShellPlatformFacts _facts(TargetPlatform platform, {bool isWeb = false}) =>
    (isWeb: isWeb, targetPlatform: platform);

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('resolveShellLayoutMode', () {
    test('mobile platforms resolve to phone or open by window size', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(
          resolveShellLayoutMode(
            isWeb: false,
            targetPlatform: platform,
            windowSize: Size.zero,
          ),
          ShellLayoutMode.phone,
        );
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

    test('width below its threshold rejects an otherwise open window', () {
      expect(
        resolveShellLayoutMode(
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
          windowSize: const Size(599, 480),
        ),
        ShellLayoutMode.phone,
      );
    });

    test('height below its threshold rejects an otherwise open window', () {
      expect(
        resolveShellLayoutMode(
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
          windowSize: const Size(600, 479),
        ),
        ShellLayoutMode.phone,
      );
    });

    test('the open thresholds are inclusive', () {
      expect(
        resolveShellLayoutMode(
          isWeb: false,
          targetPlatform: TargetPlatform.android,
          windowSize: _openSize,
        ),
        ShellLayoutMode.open,
      );
    });

    test('native desktop platforms resolve to desktop', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          resolveShellLayoutMode(
            isWeb: false,
            targetPlatform: platform,
            windowSize: _openSize,
          ),
          ShellLayoutMode.desktop,
        );
      }
    });

    test('web takes precedence over mobile platform and window size', () {
      expect(
        resolveShellLayoutMode(
          isWeb: true,
          targetPlatform: TargetPlatform.iOS,
          windowSize: _openSize,
        ),
        ShellLayoutMode.desktop,
      );
    });
  });

  group('shellLayoutModeProvider', () {
    test('Size.zero defaults mobile to phone and desktop to desktop', () {
      final mobile = ProviderContainer(
        overrides: [
          shellPlatformProvider.overrideWithValue(_facts(TargetPlatform.iOS)),
        ],
      );
      addTearDown(mobile.dispose);
      expect(mobile.read(shellLayoutModeProvider), ShellLayoutMode.phone);

      final desktop = ProviderContainer(
        overrides: [
          shellPlatformProvider.overrideWithValue(_facts(TargetPlatform.macOS)),
        ],
      );
      addTearDown(desktop.dispose);
      expect(desktop.read(shellLayoutModeProvider), ShellLayoutMode.desktop);

      final web = ProviderContainer(
        overrides: [
          shellPlatformProvider.overrideWithValue(
            _facts(TargetPlatform.iOS, isWeb: true),
          ),
        ],
      );
      addTearDown(web.dispose);
      expect(web.read(shellLayoutModeProvider), ShellLayoutMode.desktop);
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
}
