import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'frame_manifest.dart';
import 'pump_app.dart';
import 'ui_test_timeout.dart';

void main() {
  group('pumpApp', () {
    for (final size in ParitySize.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'pumps ${size.name} in ${brightness.name} at the parity size',
          timeout: uiTestTimeout,
          (tester) async {
            late BuildContext captured;
            final probe = Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            );

            await pumpApp(tester, probe, size: size, brightness: brightness);

            expect(MediaQuery.sizeOf(captured), size.size);
            expect(Theme.of(captured).brightness, brightness);
          },
        );
      }
    }
  });

  group('FrameManifest', () {
    final manifest = FrameManifest.load();

    test('exposes frame ids by area', () {
      expect(manifest.idsInArea('money'), contains('mo-budgets'));
      expect(manifest.idsInArea('states'), contains('sf-limit'));
      expect(manifest.idsInArea('money'), isNot(contains('fr-budgets')));
    });

    test('finds frames by id prefix', () {
      final budgetFrames = manifest.idsMatching('mo-budget');

      expect(budgetFrames, contains('mo-budget-add'));
      expect(budgetFrames, isNot(contains('mo-desk-budgets')));
    });

    test('lists every id once', () {
      expect(manifest.ids.length, manifest.frames.length);
    });
  });
}
