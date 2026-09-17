import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:sync/sync.dart';

/// Typed failure for a selected-but-misconfigured sync backend.
///
/// The [message] names the specific check that failed, so callers can
/// surface an actionable enrollment error without switching on a fixed
/// outcome set.
final class SyncBackendConfigurationException implements Exception {
  const SyncBackendConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'SyncBackendConfigurationException: $message';
}

/// Supabase connection details, built once at boot and never persisted.
///
/// Supabase credentials live outside [SyncMetadataSnapshot] (which carries
/// no such fields); the coordinator receives a [SupabaseConfig] built via
/// [SupabaseConfig.fromEnvironment] instead.
@immutable
final class SupabaseConfig {
  const SupabaseConfig({required this.projectUrl, required this.anonKey});

  final Uri projectUrl;
  final String anonKey;

  /// Reads the `SUPABASE_URL` / `SUPABASE_ANON_KEY` compile-time defines.
  ///
  /// Returns null when neither define was passed (both read as empty
  /// strings), meaning "not configured". A device that never selects the
  /// supabase backend must still boot, so the not-configured case never
  /// throws here; a later [SyncBackendResolver.resolve] for the supabase
  /// backend throws [SyncBackendConfigurationException] instead.
  static SupabaseConfig? fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty && key.isEmpty) return null;
    return SupabaseConfig(projectUrl: Uri.parse(url), anonKey: key);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupabaseConfig &&
          other.projectUrl == projectUrl &&
          other.anonKey == anonKey;

  @override
  int get hashCode => Object.hash(projectUrl, anonKey);
}

/// Resolves a [SyncMetadataSnapshot] plus boot-time config into a backend.
///
/// Returns null when [SyncMetadataSnapshot.backend] is null (never
/// enrolled). Throws [SyncBackendConfigurationException] for a
/// selected-but-misconfigured backend before constructing anything or
/// performing any network call. Construction itself performs no I/O: both
/// backend adapters only store fields and build an [http.Client] when one
/// is not provided.
final class SyncBackendResolver {
  const SyncBackendResolver();

  SyncBackend? resolve(
    SyncMetadataSnapshot snapshot, {
    SupabaseConfig? supabaseConfig,
    http.Client? httpClient,
  }) {
    final backend = snapshot.backend;
    if (backend == null) return null;
    return switch (backend) {
      SyncBackendKind.custom => _resolveCustom(snapshot.endpoint, httpClient),
      SyncBackendKind.supabase => _resolveSupabase(
        supabaseConfig,
        httpClient,
      ),
    };
  }

  SyncBackend _resolveCustom(String? endpoint, http.Client? httpClient) {
    final uri = endpoint == null ? null : Uri.tryParse(endpoint);
    if (uri == null || !uri.isAbsolute) {
      throw SyncBackendConfigurationException(
        'Custom sync endpoint must be an absolute URI; got "$endpoint".',
      );
    }
    if (uri.scheme != 'https') {
      throw SyncBackendConfigurationException(
        'Custom sync endpoint scheme must be "https"; got "${uri.scheme}".',
      );
    }
    if (uri.host.isEmpty) {
      throw SyncBackendConfigurationException(
        'Custom sync endpoint must have a non-empty host; got "$endpoint".',
      );
    }
    return CustomEndpointSyncBackend(baseUri: uri, client: httpClient);
  }

  SyncBackend _resolveSupabase(
    SupabaseConfig? supabaseConfig,
    http.Client? httpClient,
  ) {
    if (supabaseConfig == null) {
      throw const SyncBackendConfigurationException(
        'SupabaseConfig is required when the supabase backend is selected.',
      );
    }
    if (supabaseConfig.anonKey.isEmpty) {
      throw const SyncBackendConfigurationException(
        'SupabaseConfig.anonKey must not be empty.',
      );
    }
    final projectUrl = supabaseConfig.projectUrl;
    if (!projectUrl.isAbsolute) {
      throw SyncBackendConfigurationException(
        'SupabaseConfig.projectUrl must be an absolute URI; got "$projectUrl".',
      );
    }
    if (projectUrl.scheme != 'https') {
      throw SyncBackendConfigurationException(
        'SupabaseConfig.projectUrl scheme must be "https"; '
        'got "${projectUrl.scheme}".',
      );
    }
    if (projectUrl.host.isEmpty) {
      throw SyncBackendConfigurationException(
        'SupabaseConfig.projectUrl must have a non-empty host; '
        'got "$projectUrl".',
      );
    }
    return SupabaseSyncBackend(
      projectUrl: supabaseConfig.projectUrl,
      anonKey: supabaseConfig.anonKey,
      client: httpClient,
    );
  }
}
