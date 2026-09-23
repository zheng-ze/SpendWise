import 'package:flutter/material.dart';

@immutable
class PickerOption {
  const PickerOption({
    required this.id,
    required this.label,
    this.leading,
    this.children = const [],
  });

  final String id;
  final String label;
  final Widget? leading;
  final List<PickerOption> children;
}

@immutable
sealed class PickerOutcome {
  const PickerOutcome();
}

class PickerChose extends PickerOutcome {
  const PickerChose(this.id);

  final String id;
}

class PickerCleared extends PickerOutcome {
  const PickerCleared();
}

Future<PickerOutcome?> showTwoColumnPickerSheet({
  required BuildContext context,
  required String title,
  required List<PickerOption> groups,
  String? selectedId,
  bool allowsNone = false,
}) {
  return showModalBottomSheet<PickerOutcome>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.7,
      child: TwoColumnPickerSheet(
        title: title,
        groups: groups,
        selectedId: selectedId,
        allowsNone: allowsNone,
      ),
    ),
  );
}

class TwoColumnPickerSheet extends StatefulWidget {
  const TwoColumnPickerSheet({
    super.key,
    required this.title,
    required this.groups,
    this.selectedId,
    this.allowsNone = false,
  });

  final String title;
  final List<PickerOption> groups;
  final String? selectedId;
  final bool allowsNone;

  @override
  State<TwoColumnPickerSheet> createState() => _TwoColumnPickerSheetState();
}

class _TwoColumnPickerSheetState extends State<TwoColumnPickerSheet> {
  String? _expandedId;

  void _tapParent(PickerOption parent) {
    if (parent.children.isEmpty || _expandedId == parent.id) {
      Navigator.of(context).pop(PickerChose(parent.id));
      return;
    }
    setState(() => _expandedId = parent.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expanded = widget.groups
        .where((group) => group.id == _expandedId)
        .firstOrNull;

    return Column(
      children: [
        AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.title),
          centerTitle: true,
          leading: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          leadingWidth: 88,
          actions: [
            if (widget.allowsNone)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const PickerCleared()),
                child: const Text('None'),
              ),
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (final group in widget.groups)
                      _PickerRow(
                        option: group,
                        selected: group.id == widget.selectedId,
                        active: group.id == _expandedId,
                        onTap: () => _tapParent(group),
                      ),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: theme.dividerColor),
              Expanded(
                child: ListView(
                  children: [
                    for (final child
                        in expanded?.children ?? const <PickerOption>[])
                      _PickerRow(
                        option: child,
                        selected: child.id == widget.selectedId,
                        active: false,
                        onTap: () =>
                            Navigator.of(context).pop(PickerChose(child.id)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.option,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final PickerOption option;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.15)
        : active
        ? theme.colorScheme.surfaceContainerHighest
        : null;

    return ListTile(
      tileColor: background,
      selected: selected,
      onTap: onTap,
      leading: option.leading,
      title: Text(
        option.label,
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
      trailing: option.children.isEmpty
          ? null
          : const Icon(Icons.chevron_right, size: 18),
    );
  }
}
