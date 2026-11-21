import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/boot/app_phase.dart';
import 'package:spendwise/boot/providers.dart';

Future<Ready> readyPhase(ProviderContainer container) async {
  final boot = container.read(appBootProvider);
  while (boot.phase is! Ready) {
    await Future<void>.delayed(Duration.zero);
  }
  return boot.phase as Ready;
}
