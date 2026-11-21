part of '../recycle_bin_sections.dart';

// MARK: - Footer Hint

class BinFooterHint extends StatelessWidget {
  const BinFooterHint({super.key});

  static const _hint = 'Swipe right to restore or left to delete permanently.';

  @override
  Widget build(BuildContext context) {
    return Text(
      _hint,
      textAlign: TextAlign.center,
      style: context.text.body.copyWith(
        fontWeight: SpendWiseText.semibold,
        color: context.colors.subtext,
      ),
    );
  }
}

// MARK: - Empty State

class BinEmptyState extends StatelessWidget {
  const BinEmptyState({super.key});

  static const _emptyIcon = Icons.delete_outline;
  static const _emptyTitle = 'Recycle bin is empty';

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EmptyState(icon: _emptyIcon, title: _emptyTitle),
    );
  }
}
