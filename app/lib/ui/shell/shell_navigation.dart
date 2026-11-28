import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shell_providers.dart';

@immutable
class ShellRequest {
  const ShellRequest({required this.occurrence});

  final int occurrence;

  @override
  bool operator ==(Object other) =>
      other is ShellRequest && other.occurrence == occurrence;

  @override
  int get hashCode => occurrence.hashCode;
}

class ShellNavigationController extends Notifier<ShellRequest?> {
  int _lastOccurrence = 0;

  @override
  ShellRequest? build() => null;

  void openHistoryTrends() {
    _lastOccurrence += 1;
    state = ShellRequest(occurrence: _lastOccurrence);
    ref.read(selectedDestinationProvider.notifier).state =
        ShellDestination.history;
  }

  void consume(ShellRequest request) {
    if (state != request) return;
    state = null;
  }
}

final shellNavigationProvider =
    NotifierProvider<ShellNavigationController, ShellRequest?>(
      ShellNavigationController.new,
    );
