part of '../recycle_bin_sections.dart';

// MARK: - Footer Hint

class BinFooterHint extends StatelessWidget {
  const BinFooterHint({super.key});

  static const _hint = 'Swipe right to restore or left to delete permanently.';
  static const _fontSize = 12.0;

  @override
  Widget build(BuildContext context) {
    return Text(
      _hint,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: _fontSize, color: context.colors.subtext),
    );
  }
}

// MARK: - Empty State

class BinEmptyState extends StatelessWidget {
  const BinEmptyState({super.key});

  static const _emptyTitle = 'Recycle bin is empty';
  static const _emptyFontSize = 14.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _emptyTitle,
        style: TextStyle(
          fontSize: _emptyFontSize,
          color: context.colors.subtext,
        ),
      ),
    );
  }
}
