import 'package:flutter/material.dart';

class StatementDayPicker extends StatelessWidget {
  const StatementDayPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int? selected;
  final ValueChanged<int> onSelected;

  static const _sheetHeightFactor = 0.7;

  static const _firstDay = 1;

  static const _lastDay = 28;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Statement Day'),
      trailing: Text(selected?.toString() ?? 'Select'),
      onTap: () => _pick(context),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: _sheetHeightFactor,
        child: SafeArea(
          child: ListView(
            children: [
              for (var day = _firstDay; day <= _lastDay; day++)
                ListTile(
                  title: Text('$day'),
                  trailing: day == selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(day),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) onSelected(chosen);
  }
}
