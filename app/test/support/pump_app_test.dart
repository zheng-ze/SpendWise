import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';
import 'ui_test_timeout.dart';

Future<BuildContext> pumpProbe(
  WidgetTester tester,
  ParitySize size,
  Brightness brightness,
) async {
  late BuildContext captured;
  final probe = Builder(
    builder: (context) {
      captured = context;
      return const SizedBox.shrink();
    },
  );
  await pumpApp(tester, probe, size: size, brightness: brightness);
  return captured;
}

void main() {
  group('pumpApp', () {
    for (final size in ParitySize.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'pumps ${size.name} in ${brightness.name} at the parity size',
          timeout: uiTestTimeout,
          (tester) async {
            final context = await pumpProbe(tester, size, brightness);

            expect(MediaQuery.sizeOf(context), size.size);
            expect(Theme.of(context).brightness, brightness);
          },
        );
      }
    }

    testWidgets(
      'pumps an endless animation when settling is off',
      timeout: uiTestTimeout,
      (tester) async {
        await pumpApp(tester, const CircularProgressIndicator(), settle: false);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );
  });
}
