import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('Decimal is nameable through the barrel alone', () {
    final Decimal amount = Decimal.fromInt(-25);

    expect(amount, Decimal.parse('-25'));
    expect(
      Entry(amount: amount, name: 'rent', sourceID: _accountID).amount,
      isA<Decimal>(),
    );
  });
}

const _accountID = '00000000-0000-4000-8000-000000000001';
