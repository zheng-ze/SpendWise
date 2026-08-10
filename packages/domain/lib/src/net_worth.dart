import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

@immutable
class NetWorth {
  const NetWorth(this.asset, this.liability);

  final Decimal asset;

  /// A positive magnitude, not a negative balance.
  final Decimal liability;

  @override
  bool operator ==(Object other) {
    return other is NetWorth &&
        other.asset == asset &&
        other.liability == liability;
  }

  @override
  int get hashCode => Object.hash(asset, liability);
}
