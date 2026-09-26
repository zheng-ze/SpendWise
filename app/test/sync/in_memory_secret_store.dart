import 'package:spendwise/sync/secret_store.dart';

final class InMemorySecretStore implements SecretStore {
  final _values = <String, String>{};
  final reads = <String>[];
  final writes = <String>[];
  final deletes = <String>[];
  Object? readFailure;
  String? readFailureKey;
  Object? deleteFailure;

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    if (readFailure case final failure?) {
      if (readFailureKey == null || readFailureKey == key) throw failure;
    }
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes.add(key);
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletes.add(key);
    if (deleteFailure case final failure?) throw failure;
    _values.remove(key);
  }
}
