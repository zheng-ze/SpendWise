import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

@immutable
class TopCategoriesViewState {
  const TopCategoriesViewState({required this.body});

  final TopCategoriesBody body;
}

sealed class TopCategoriesBody {
  const TopCategoriesBody();
}

final class TopCategoriesLoadingBody extends TopCategoriesBody {
  const TopCategoriesLoadingBody();
}

final class TopCategoriesErrorBody extends TopCategoriesBody {
  const TopCategoriesErrorBody();
}

final class TopCategoriesCompactBody extends TopCategoriesBody {
  const TopCategoriesCompactBody();
}

@immutable
final class TopCategoriesReadyBody extends TopCategoriesBody {
  TopCategoriesReadyBody({
    required this.total,
    required this.sourceRevision,
    required List<TopCategoryRow> rows,
  }) : rows = List.unmodifiable(rows);

  final Decimal total;
  final int sourceRevision;
  final List<TopCategoryRow> rows;
}

@immutable
class TopCategoryRow {
  const TopCategoryRow({
    required this.bucketID,
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.sharePercent,
  });

  final String? bucketID;
  final String name;
  final IconData icon;
  final Color color;
  final Decimal amount;
  final Decimal sharePercent;
}
