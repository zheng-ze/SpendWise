part of '../../sync.dart';

// MARK: - Payload Field Readers

extension PayloadCodecDecodePrimitives on PayloadCodec {
  T _fromCode<T>(String field, T Function() decode) {
    try {
      return decode();
    } catch (_) {
      throw PayloadDecodeError('Field $field is invalid.');
    }
  }

  String _str(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) {
      throw PayloadDecodeError('Field $key must be a string.');
    }
    return value;
  }

  String? _strNullable(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! String) {
      throw PayloadDecodeError('Field $key must be a string or null.');
    }
    return value as String?;
  }

  int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw PayloadDecodeError('Field $key must be an integer.');
    }
    return value;
  }

  int? _intNullable(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value != null && value is! int) {
      throw PayloadDecodeError('Field $key must be an integer or null.');
    }
    return value as int?;
  }

  bool _bool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw PayloadDecodeError('Field $key must be a boolean.');
    }
    return value;
  }

  List<Object?> _list(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! List<Object?>) {
      throw PayloadDecodeError('Field $key must be a list.');
    }
    return value;
  }

  Map<String, Object?> _object(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! Map<String, Object?>) {
      throw PayloadDecodeError('Field $key must be an object.');
    }
    return value;
  }

  List<String> _stringList(Map<String, Object?> map, String key) {
    final values = _list(map, key);
    return <String>[
      for (final value in values)
        if (value is! String)
          throw PayloadDecodeError('Field $key must hold strings.')
        else
          value,
    ];
  }
}
