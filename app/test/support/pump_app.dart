import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:spendwise/boot/providers.dart';
import 'package:spendwise/ledger/analysis_cache.dart';
import 'package:spendwise/ledger/ledger.dart';
import 'package:spendwise/ui/theme/spendwise_theme.dart';

enum ParitySize {
  phone(Size(320, 760)),
  compact(Size(320, 560)),
  desktop(Size(1440, 900)),
  desktopNarrow(Size(900, 700));

  const ParitySize(this.size);

  final Size size;
}

const _devicePixelRatio = 1.0;

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Ledger? ledger,
  DateTime? today,
  ParitySize size = ParitySize.phone,
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
}) async {
  tester.view.devicePixelRatio = _devicePixelRatio;
  tester.view.physicalSize = size.size;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      analysisComputeRunnerProvider.overrideWithValue(syncComputeRunner),
      if (ledger != null) ledgerProvider.overrideWithValue(ledger),
      if (today != null) clockProvider.overrideWithValue(() => today),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  final app = MaterialApp(theme: buildSpendWiseTheme(brightness), home: child);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pumpAndSettle();
}
