part of '../../sync.dart';

// MARK: - Payload Decode Error

final class PayloadDecodeError implements FormatException {
  const PayloadDecodeError(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'PayloadDecodeError: $message';
}
