import 'dart:io';
import 'dart:convert';
import 'package:sembast/sembast_io.dart';
import 'package:path/path.dart' as p;

final _store = intMapStoreFactory.store('fuel_logs');

Future<void> main() async {
  // Old location (where migration data was created)
  final oldDbPath = p.join('/workspaces/fuel', '.sembast_data', 'fuel.db');
  final oldDb = await databaseFactoryIo.openDatabase(oldDbPath);

  // Get records from old DB
  final oldRecords = await _store.find(oldDb);
  print('Found ${oldRecords.length} records in old database');

  if (oldRecords.isEmpty) {
    print('No records to migrate.');
    await oldDb.close();
    return;
  }

  // Export to JSON for reference
  final exportDir = Directory('/workspaces/fuel/export');
  if (!await exportDir.exists()) await exportDir.create(recursive: true);

  final jsonRecords =
      oldRecords.map((r) => Map<String, dynamic>.from(r.value)).toList();

  final jsonFile = File(p.join(exportDir.path, 'fuel_logs_export.json'));
  await jsonFile.writeAsString(
    _prettyJson(jsonRecords),
  );
  print('Exported ${jsonRecords.length} records to ${jsonFile.path}');

  // Create new location for Android app to use
  final newDir =
      Directory(p.join(Directory.systemTemp.path, 'fuel_app', '.sembast_data'));
  if (!await newDir.exists()) await newDir.create(recursive: true);
  final newDbPath = p.join(newDir.path, 'fuel.db');

  final newDb = await databaseFactoryIo.openDatabase(newDbPath);

  // Copy records to new DB
  for (final record in oldRecords) {
    await _store.add(newDb, Map<String, dynamic>.from(record.value));
  }

  final newCount = (await _store.find(newDb)).length;
  print('Migrated ${oldRecords.length} records to new location: $newDbPath');
  print('Verified: new DB now has $newCount records');

  await oldDb.close();
  await newDb.close();
}

String _prettyJson(dynamic json) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(json);
}
