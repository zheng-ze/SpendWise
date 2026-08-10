import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newID() => _uuid.v4();

/// Uuids only. Never use on an id whose alphabet is case-sensitive.
String normalizedID(String id) => id.toLowerCase();

String? normalizedOptionalID(String? id) =>
    id == null ? null : normalizedID(id);

String normalizedOrNewID(String? id) => normalizedOptionalID(id) ?? newID();
