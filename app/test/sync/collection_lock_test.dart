import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/collection_lock.dart';
import 'package:sync/sync.dart';

void main() {
  group('same collection', () {
    test('overlapping bodies run serialized in arrival order', () async {
      final lock = CollectionLock();
      final events = <String>[];

      Future<String> slowBody() async {
        events.add('first-start');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        events.add('first-end');
        return 'first';
      }

      final first = lock.withLock(SyncCollection.entries, slowBody);
      final second = lock.withLock(SyncCollection.entries, () async {
        events.add('second-start');
        return 'second';
      });

      expect(await first, 'first');
      expect(await second, 'second');
      expect(events, ['first-start', 'first-end', 'second-start']);
    });

    test('three overlapping bodies serialize end to end', () async {
      final lock = CollectionLock();
      final events = <String>[];

      Future<void> body(String name) =>
          lock.withLock(SyncCollection.plans, () async {
            events.add('$name-start');
            await Future<void>.delayed(const Duration(milliseconds: 5));
            events.add('$name-end');
          });

      await Future.wait([body('a'), body('b'), body('c')]);

      expect(events, [
        'a-start',
        'a-end',
        'b-start',
        'b-end',
        'c-start',
        'c-end',
      ]);
    });
  });

  group('different collections', () {
    test('a slow lock on one collection does not block another', () async {
      final lock = CollectionLock();
      final releaseA = Completer<void>();
      final enteredB = Completer<void>();

      final a = lock.withLock(SyncCollection.entries, () async {
        await releaseA.future;
        return 'a';
      });
      final b = lock.withLock(SyncCollection.categories, () async {
        enteredB.complete();
        return 'b';
      });

      await enteredB.future.timeout(const Duration(seconds: 5));
      releaseA.complete();

      expect(await b, 'b');
      expect(await a, 'a');
    });
  });

  group('failure handling', () {
    test('a throwing body does not poison the next caller', () async {
      final lock = CollectionLock();

      await expectLater(
        lock.withLock(
          SyncCollection.entries,
          () async => throw StateError('boom'),
        ),
        throwsStateError,
      );

      expect(await lock.withLock(SyncCollection.entries, () async => 42), 42);
    });

    test('waiters chained behind a failure still run serialized', () async {
      final lock = CollectionLock();
      final events = <String>[];

      final first = lock.withLock(SyncCollection.entries, () async {
        events.add('first-start');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        events.add('first-throws');
        throw StateError('boom');
      });
      final second = lock.withLock(SyncCollection.entries, () async {
        events.add('second-start');
        return 'second';
      });

      await expectLater(first, throwsStateError);
      expect(await second, 'second');
      expect(events, ['first-start', 'first-throws', 'second-start']);
    });
  });
}
