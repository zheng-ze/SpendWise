part of '../recycle_bin_sections.dart';

// MARK: - Empty State

class BinEmptyState extends StatelessWidget {
  const BinEmptyState({super.key});

  static const _emptyTitle = 'Recycle bin is empty';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _emptyTitle,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
