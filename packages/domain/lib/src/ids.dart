import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newID() => _uuid.v4();

/// Uuids only. Never use on an id whose alphabet is case-sensitive.
String canonicalID(String id) => id.toLowerCase();

String? canonicalOptionalID(String? id) => id == null ? null : canonicalID(id);

String canonicalOrNewID(String? id) => canonicalOptionalID(id) ?? newID();
