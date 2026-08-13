import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:spendwise/persistence/database_connection.dart';

Future<OpenedConnection> openConnection(String name) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File(p.join(directory.path, '$name.sqlite'));
  return OpenedConnection(NativeDatabase(file), isDurable: true);
}
