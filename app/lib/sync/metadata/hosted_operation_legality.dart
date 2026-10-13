part of '../sync_metadata_store.dart';

// MARK: - Hosted Operation Legality

@immutable
sealed class HostedOperationLegality {
  const HostedOperationLegality();

  bool get isLegal;
}

@immutable
final class HostedOperationLegal extends HostedOperationLegality {
  const HostedOperationLegal();

  @override
  bool get isLegal => true;

  @override
  bool operator ==(Object other) => other is HostedOperationLegal;

  @override
  int get hashCode => runtimeType.hashCode;
}

@immutable
final class HostedOperationIllegal extends HostedOperationLegality {
  const HostedOperationIllegal(this.reason);

  final String reason;

  @override
  bool get isLegal => false;

  @override
  bool operator ==(Object other) =>
      other is HostedOperationIllegal && other.reason == reason;

  @override
  int get hashCode => Object.hash(runtimeType, reason);
}
