import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';

void main() async {
  // Open the runtime DB location
  final dir = Directory(p.join(Directory.systemTemp.path, 'fuel_app', '.sembast_data'));
  if (!await dir.exists()) {
    print('DB directory does not exist. Nothing to clean.');
    return;
  }

  final dbPath = p.join(dir.path, 'fuel.db');
  if (!File(dbPath).existsSync()) {
    print('DB file does not exist. Nothing to clean.');
    return;
  }

  final db = await databaseFactoryIo.openDatabase(dbPath);
  final store = intMapStoreFactory.store('fuel_logs');

  try {
    final records = await store.find(db);
    print('Found ${records.length} records in DB');

    // Deduplicate by date + odometer (unique identifier for a refuel)
    final seen = <String>{};
    final duplicates = <int>[];

    for (final record in records) {
      final json = record.value as Map;
      final date = json['date'] as String?;
      final odometer = json['odometer'] as int?;
      final key = '$date-$odometer';

      if (seen.contains(key)) {
        duplicates.add(record.key);
        print('Duplicate found: $key (key: ${record.key})');
      } else {
        seen.add(key);
      }
    }

    if (duplicates.isEmpty) {
      print('No duplicates found. DB is clean.');
    } else {
      print('Removing ${duplicates.length} duplicate records...');
      for (final key in duplicates) {
        await store.record(key).delete(db);
      }
      print('Removed ${duplicates.length} duplicates.');

      final updated = await store.find(db);
      print('DB now has ${updated.length} records.');
    }
  } finally {
    await db.close();
  }
}
