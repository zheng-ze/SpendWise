part of '../sync_metadata_store.dart';

// MARK: - Device Binding State

enum SyncDeviceBindingState {
  notApplicable(0),
  authorizationRequired(1),
  bound(2);

  const SyncDeviceBindingState(this.code);

  final int code;

  static SyncDeviceBindingState fromCode(int code) => values.firstWhere(
    (state) => state.code == code,
    orElse: () =>
        throw FormatException('Unknown sync device binding state: $code.'),
  );
}
