import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spendwise/ui/common/base/flow_base.dart';
import 'package:spendwise/ui/stats/trends_screen.dart';

class TrendsFlow extends FlowBase<Never> {
  const TrendsFlow({super.key, super.onEnded});

  @override
  ConsumerState<TrendsFlow> createState() => _TrendsFlowState();
}

class _TrendsFlowState extends FlowBaseState<Never, TrendsFlow> {
  @override
  void Function() subscribeToStep(void Function(Never? step) handle) => () {};

  @override
  void handleStep(BuildContext context, Never step) {}

  @override
  Widget buildRoot(BuildContext context) =>
      TrendsScreen(onBackPressed: showsOwnBackButton ? goBack : null);
}
