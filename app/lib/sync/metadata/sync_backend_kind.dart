part of '../sync_metadata_store.dart';

// MARK: - Backend Kind

enum SyncBackendKind {
  supabase('supabase'),
  custom('custom');

  const SyncBackendKind(this.code);

  final String code;

  static SyncBackendKind? fromCode(String? code) {
    if (code == null) return null;
    return values.firstWhere(
      (kind) => kind.code == code,
      orElse: () => throw FormatException('Unknown sync backend: $code.'),
    );
  }
}
