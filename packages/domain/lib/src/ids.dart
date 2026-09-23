import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newID() => _uuid.v4();

String normalizedID(String id) => id.toLowerCase();

String? normalizedOptionalID(String? id) =>
    id == null ? null : normalizedID(id);

String normalizedOrNewID(String? id) => normalizedOptionalID(id) ?? newID();
