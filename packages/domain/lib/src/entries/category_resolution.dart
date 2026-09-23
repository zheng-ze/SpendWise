import 'package:domain/src/ids.dart';
import 'package:meta/meta.dart';

@immutable
sealed class CategoryResolution {
  const CategoryResolution();
}

final class Excluded extends CategoryResolution {
  const Excluded();

  @override
  bool operator ==(Object other) => other is Excluded;

  @override
  int get hashCode => (Excluded).hashCode;

  @override
  String toString() => 'Excluded()';
}

final class Uncategorized extends CategoryResolution {
  const Uncategorized();

  @override
  bool operator ==(Object other) => other is Uncategorized;

  @override
  int get hashCode => (Uncategorized).hashCode;

  @override
  String toString() => 'Uncategorized()';
}

final class InCategory extends CategoryResolution {
  InCategory(String id) : id = normalizedID(id);

  final String id;

  @override
  bool operator ==(Object other) => other is InCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'InCategory($id)';
}
