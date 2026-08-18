import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/ui/transactions/entry_transfer_scope.dart';

void main() {
  Decimal dec(String value) => Decimal.parse(value);

  final a = 'a0000000-0000-0000-0000-000000000001';
  final b = 'a0000000-0000-0000-0000-000000000002';

  Entry transfer() =>
      Entry(amount: dec('50'), name: 'move', sourceID: a, destinationID: b);

  test('destination in scope, source out, is a gain', () {
    final sign = transfer().transferScopeSign({b});

    expect(sign, TransferScopeSign.gain);
  });

  test('source in scope, destination out, is a loss', () {
    final sign = transfer().transferScopeSign({a});

    expect(sign, TransferScopeSign.loss);
  });

  test('both endpoints in scope is neutral', () {
    final sign = transfer().transferScopeSign({a, b});

    expect(sign, TransferScopeSign.neutral);
  });

  test('neither endpoint in scope is neutral', () {
    final sign = transfer().transferScopeSign({
      'a0000000-0000-0000-0000-000000000099',
    });

    expect(sign, TransferScopeSign.neutral);
  });
}
