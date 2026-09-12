import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
      'packages/sync has no Flutter, dart:ui, Supabase-Flutter, or app imports',
      () {
    final root = _findPackageRoot();
    final lib = Directory('${root.path}/lib');
    final violations = <String>[];
    const forbidden = <String>[
      'package:flutter/',
      'dart:ui',
      'package:supabase_flutter/',
      'package:spendwise/',
    ];

    for (final entity in lib.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final importPrefix in forbidden) {
        if (source.contains(importPrefix)) {
          violations.add('${entity.path}: $importPrefix');
        }
      }
    }

    final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
    for (final dependency in const <String>['flutter:', 'supabase_flutter:']) {
      if (RegExp('^\\s*${RegExp.escape(dependency)}', multiLine: true)
          .hasMatch(pubspec)) {
        violations.add('pubspec.yaml: $dependency');
      }
    }
    if (pubspec.contains('sdk: flutter')) {
      violations.add('pubspec.yaml: sdk: flutter');
    }

    expect(
      violations,
      isEmpty,
      reason: 'packages/sync must remain compile-enforced pure Dart.',
    );
  });
}

Directory _findPackageRoot() {
  final current = Directory.current;
  if (File('${current.path}/pubspec.yaml').existsSync() &&
      Directory('${current.path}/lib').existsSync()) {
    return current;
  }

  final nested = Directory('${current.path}/packages/sync');
  if (File('${nested.path}/pubspec.yaml').existsSync() &&
      Directory('${nested.path}/lib').existsSync()) {
    return nested;
  }

  throw StateError(
    'Could not locate packages/sync. Run tests from the package or repository root.',
  );
}
