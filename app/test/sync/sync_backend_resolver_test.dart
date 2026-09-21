import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/sync/sync_backend_resolver.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:sync/sync.dart';

SyncMetadataSnapshot snapshotOf({
  required SyncBackendKind? backend,
  String? endpoint,
}) => SyncMetadataSnapshot(
  backend: backend,
  endpoint: endpoint,
  phase: SyncEnrollmentPhase.notEnrolled,
  writeEnabled: false,
  watermarks: const {},
);

void main() {
  const resolver = SyncBackendResolver();

  group('custom backend', () {
    test('a valid absolute https URI resolves to a custom backend', () {
      final backend = resolver.resolve(
        snapshotOf(
          backend: SyncBackendKind.custom,
          endpoint: 'https://sync.example.com',
        ),
      );

      expect(backend, isA<CustomEndpointSyncBackend>());
      expect(
        (backend as CustomEndpointSyncBackend).baseUri,
        Uri.parse('https://sync.example.com'),
      );
    });

    test('a relative URI throws before any backend is constructed', () {
      expect(
        () => resolver.resolve(
          snapshotOf(backend: SyncBackendKind.custom, endpoint: 'sync/push'),
        ),
        throwsA(
          isA<SyncBackendConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('absolute'),
          ),
        ),
      );
    });

    test('an https URI with an empty host throws', () {
      expect(
        () => resolver.resolve(
          snapshotOf(backend: SyncBackendKind.custom, endpoint: 'https://'),
        ),
        throwsA(
          isA<SyncBackendConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('host'),
          ),
        ),
      );
    });

    test('a missing endpoint throws', () {
      expect(
        () => resolver.resolve(snapshotOf(backend: SyncBackendKind.custom)),
        throwsA(isA<SyncBackendConfigurationException>()),
      );
    });

    test('a plain http URI throws', () {
      expect(
        () => resolver.resolve(
          snapshotOf(
            backend: SyncBackendKind.custom,
            endpoint: 'http://sync.example.com',
          ),
        ),
        throwsA(
          isA<SyncBackendConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('https'),
          ),
        ),
      );
    });

    test('an unrelated scheme throws', () {
      expect(
        () => resolver.resolve(
          snapshotOf(
            backend: SyncBackendKind.custom,
            endpoint: 'ftp://sync.example.com/sync',
          ),
        ),
        throwsA(isA<SyncBackendConfigurationException>()),
      );
    });
  });

  group('supabase backend', () {
    test('a complete config resolves to a supabase backend', () {
      final config = SupabaseConfig(
        projectUrl: Uri.parse('https://example.supabase.co'),
        anonKey: 'anon-key',
      );

      final backend = resolver.resolve(
        snapshotOf(backend: SyncBackendKind.supabase),
        supabaseConfig: config,
      );

      expect(backend, isA<SupabaseSyncBackend>());
      final supabase = backend as SupabaseSyncBackend;
      expect(supabase.projectUrl, config.projectUrl);
      expect(supabase.anonKey, config.anonKey);
    });

    test('a null config throws before any backend is constructed', () {
      expect(
        () => resolver.resolve(snapshotOf(backend: SyncBackendKind.supabase)),
        throwsA(isA<SyncBackendConfigurationException>()),
      );
    });

    test('an empty anon key throws', () {
      final config = SupabaseConfig(
        projectUrl: Uri.parse('https://example.supabase.co'),
        anonKey: '',
      );

      expect(
        () => resolver.resolve(
          snapshotOf(backend: SyncBackendKind.supabase),
          supabaseConfig: config,
        ),
        throwsA(isA<SyncBackendConfigurationException>()),
      );
    });

    test('an empty projectUrl throws before any backend is constructed', () {
      // Covers the half-configured shape: SUPABASE_ANON_KEY set via
      // --dart-define while SUPABASE_URL is not, which reaches resolve()
      // as an empty, non-absolute projectUrl with a real anon key.
      final config = SupabaseConfig(
        projectUrl: Uri.parse(''),
        anonKey: 'anon-key',
      );

      expect(
        () => resolver.resolve(
          snapshotOf(backend: SyncBackendKind.supabase),
          supabaseConfig: config,
        ),
        throwsA(
          isA<SyncBackendConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('absolute'),
          ),
        ),
      );
    });

    test('a non-https projectUrl throws', () {
      final config = SupabaseConfig(
        projectUrl: Uri.parse('http://project.supabase.co'),
        anonKey: 'anon-key',
      );

      expect(
        () => resolver.resolve(
          snapshotOf(backend: SyncBackendKind.supabase),
          supabaseConfig: config,
        ),
        throwsA(
          isA<SyncBackendConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('https'),
          ),
        ),
      );
    });

    test('a projectUrl with an empty host throws', () {
      final config = SupabaseConfig(
        projectUrl: Uri.parse('https://'),
        anonKey: 'anon-key',
      );

      expect(
        () => resolver.resolve(
          snapshotOf(backend: SyncBackendKind.supabase),
          supabaseConfig: config,
        ),
        throwsA(
          isA<SyncBackendConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('host'),
          ),
        ),
      );
    });
  });

  group('no backend selected', () {
    test('a never-enrolled snapshot resolves to null without throwing', () {
      expect(resolver.resolve(snapshotOf(backend: null)), isNull);
    });
  });

  group('SupabaseConfig.fromEnvironment', () {
    test('without compile-time defines it reports not-configured', () {
      // No --dart-define flags are passed to the test runner, so both
      // SUPABASE_URL and SUPABASE_ANON_KEY read as empty strings.
      expect(SupabaseConfig.fromEnvironment(), isNull);
    });
  });
}
