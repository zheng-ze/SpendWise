final class XlsxSheet {
  const XlsxSheet({required this.rows, required this.date1904});

  final List<List<String>> rows;

  final bool date1904;
}

final class XlsxReadFailure implements Exception {
  const XlsxReadFailure(this.message, {this.cause});

  final String message;

  final Object? cause;

  @override
  String toString() => 'XlsxReadFailure: $message';
}
