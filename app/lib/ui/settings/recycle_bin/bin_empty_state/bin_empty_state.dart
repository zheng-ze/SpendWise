part of '../recycle_bin_sections.dart';

// MARK: - Footer Hint

class BinFooterHint extends StatelessWidget {
  const BinFooterHint({super.key});

  static const _hint = 'Swipe right to restore or left to delete permanently.';
  static const _fontSize = 12.0;
  static const _fontWeight = FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    return Text(
      _hint,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: _fontSize,
        fontWeight: _fontWeight,
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
