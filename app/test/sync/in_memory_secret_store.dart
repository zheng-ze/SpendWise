import 'package:spendwise/sync/secret_store.dart';

final class InMemorySecretStore implements SecretStore {
  final _values = <String, String>{};
  final reads = <String>[];
  Object? readFailure;

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    if (readFailure case final failure?) throw failure;
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
