import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> openConnection(String name) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(p.join(directory.path, '$name.sqlite'));
  return NativeDatabase(file);
}
