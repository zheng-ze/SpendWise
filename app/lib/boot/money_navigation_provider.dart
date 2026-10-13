import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/ui/accounts/money_navigation.dart';

final moneyNavigatorObserverProvider = Provider<MoneyNavigatorObserver>(
  (ref) => MoneyNavigatorObserver(),
);
