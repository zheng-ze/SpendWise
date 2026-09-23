import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

@immutable
class NetWorth {
  const NetWorth(this.asset, this.liability);

  final Decimal asset;

  final Decimal liability;

  @override
  bool operator ==(Object other) {
    return other is NetWorth &&
        other.asset == asset &&
        other.liability == liability;
  }

  @override
  int get hashCode => Object.hash(asset, liability);

  @override
  String toString() => 'NetWorth(asset: $asset, liability: $liability)';
}
