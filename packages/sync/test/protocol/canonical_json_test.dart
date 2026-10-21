import 'package:sync/sync.dart';
import 'package:test/test.dart';

void main() {
  test('canonical JSON sorts keys by Unicode code point, not UTF-16', () {
    const bmpPrivateUse = '\uE000';
    const supplementary = '\u{10000}';

    expect(
      canonicalJson(<String, Object?>{
        supplementary: 2,
        bmpPrivateUse: 1,
      }),
      '{"$bmpPrivateUse":1,"$supplementary":2}',
    );
  });

  test('canonical JSON rejects doubles', () {
    expect(() => canonicalJson(1.5), throwsArgumentError);
  });
}
