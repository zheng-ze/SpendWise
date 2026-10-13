part of '../category_map.dart';

// MARK: - Tile

@immutable
class CategoryMapTile {
  const CategoryMapTile({
    required this.label,
    required this.share,
    required this.color,
  });

  final String label;

  final double share;

  final Color color;
}
