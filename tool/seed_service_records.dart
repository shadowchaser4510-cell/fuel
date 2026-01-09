import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';

void main() async {
  final dir = Directory(p.join(Directory.systemTemp.path, 'fuel_app', '.sembast_data'));
  if (!await dir.exists()) await dir.create(recursive: true);

  final dbPath = p.join(dir.path, 'fuel.db');
  final db = await databaseFactoryIo.openDatabase(dbPath);
  final serviceStore = intMapStoreFactory.store('service_records');

  // Service records to seed
  final services = [
    {
      'date': DateTime(2024, 8, 16).toIso8601String(),
      'odometer': 1410,
      'cost': 0.0,
    },
    {
      'date': DateTime(2024, 11, 7).toIso8601String(),
      'odometer': 2958,
      'cost': 1955.0,
    },
    {
      'date': DateTime(2025, 6, 14).toIso8601String(),
      'odometer': 5797,
      'cost': 82117.0,
    },
    {
      'date': DateTime(2025, 12, 6).toIso8601String(),
      'odometer': 9919,
      'cost': 2753.0,
    },
  ];

  try {
    for (final service in services) {
      await serviceStore.add(db, service);
    }
    print('Seeded ${services.length} service records');
  } finally {
    await db.close();
  }
}
