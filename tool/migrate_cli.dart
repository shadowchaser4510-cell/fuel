import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:fuel_tracker/api_service.dart';
import 'package:fuel_tracker/hive_adapters/fuel_log_adapter.dart';

Future<void> main() async {
  // Use a local directory inside the project for Hive storage
  final dir = Directory(p.join(Directory.current.path, '.hive_data'));
  if (!await dir.exists()) await dir.create(recursive: true);

  Hive.init(dir.path);
  Hive.registerAdapter(FuelLogAdapter());

  stdout.writeln('Deprecated: remote migration removed. Use CSV importer');
  exit(0);

}
