import 'package:flutter/material.dart';

import 'package:spendwise/ui/format/amount_input.dart';

class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.allowsNegative,
    this.hintText = 'Amount',
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool allowsNegative;
  final String hintText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  late bool _hasText = widget.controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncPrefix);
  }

  @override
  void didUpdateWidget(AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncPrefix);
      widget.controller.addListener(_syncPrefix);
      _syncPrefix();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncPrefix);
    super.dispose();
  }

  void _syncPrefix() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      textAlign: TextAlign.end,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: widget.allowsNegative,
      ),
      inputFormatters: [
        AmountInputFormatter(allowsNegative: widget.allowsNegative),
      ],
      style: Theme.of(context).textTheme.titleMedium,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: InputBorder.none,
        prefixText: _hasText ? r'$' : null,
      ),
    );
  }
}
