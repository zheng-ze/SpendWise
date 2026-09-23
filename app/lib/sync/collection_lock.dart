import 'dart:async';

import 'package:sync/sync.dart';

final class CollectionLock {
  final Map<SyncCollection, Future<void>> _tails = {};

  Future<T> withLock<T>(
    SyncCollection collection,
    Future<T> Function() body,
  ) async {
    final prior = _tails[collection];
    final gate = Completer<void>();
    _tails[collection] = gate.future;
    try {
      if (prior != null) await prior;
      return await body();
    } finally {
      if (identical(_tails[collection], gate.future)) {
        _tails.remove(collection);
      }
      gate.complete();
    }
  }
}
