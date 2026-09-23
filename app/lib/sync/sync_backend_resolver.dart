import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise/sync/custom_endpoint_validator.dart';
import 'package:spendwise/sync/sync_metadata_store.dart';
import 'package:sync/sync.dart';

final class SyncBackendConfigurationException implements Exception {
  const SyncBackendConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'SyncBackendConfigurationException: $message';
}

@immutable
final class SupabaseConfig {
  const SupabaseConfig({required this.projectUrl, required this.anonKey});

  final Uri projectUrl;
  final String anonKey;

  static SupabaseConfig? fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty && key.isEmpty) return null;
    return SupabaseConfig(projectUrl: Uri.tryParse(url) ?? Uri(), anonKey: key);
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
      SyncBackendKind.supabase => _resolveSupabase(supabaseConfig, httpClient),
    };
  }

  SyncBackend _resolveCustom(String? endpoint, http.Client? httpClient) {
    final validation = CustomEndpointValidation.validate(endpoint);
    return switch (validation) {
      ValidCustomEndpoint(:final uri) => CustomEndpointSyncBackend(
        baseUri: uri,
        client: httpClient,
      ),
      InvalidCustomEndpoint(:final failure) => throw failure,
    };
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
