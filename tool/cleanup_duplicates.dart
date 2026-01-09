import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';

void main() async {
  final dir = Directory(p.join(Directory.systemTemp.path, 'fuel_app', '.sembast_data'));
  if (!await dir.exists()) {
    print('DB directory does not exist.');
    return;
  }

  final dbPath = p.join(dir.path, 'fuel.db');
  if (!File(dbPath).existsSync()) {
    print('DB file does not exist.');
    return;
  }

  final db = await databaseFactoryIo.openDatabase(dbPath);
  final fuelStore = intMapStoreFactory.store('fuel_logs');
  final serviceStore = intMapStoreFactory.store('service_records');

  try {
    // Deduplicate fuel logs by odometer
    final fuelRecords = await fuelStore.find(db);
    print('Fuel logs before dedup: ${fuelRecords.length}');

    final Map<int, List<RecordSnapshot>> byOdometer = {};
    for (final record in fuelRecords) {
      final json = Map<String, dynamic>.from(record.value as Map);
      final odometer = json['odometer'] as int;
      byOdometer.putIfAbsent(odometer, () => []).add(record);
    }

    int deletedCount = 0;
    for (final odometerGroup in byOdometer.values) {
      if (odometerGroup.length > 1) {
        odometerGroup.sort((a, b) {
          final jsonA = Map<String, dynamic>.from(a.value as Map);
          final jsonB = Map<String, dynamic>.from(b.value as Map);
          final dateA = DateTime.parse(jsonA['date'] as String);
          final dateB = DateTime.parse(jsonB['date'] as String);
          return dateA.compareTo(dateB);
        });
        
        for (int i = 1; i < odometerGroup.length; i++) {
          await fuelStore.record(odometerGroup[i].key as int).delete(db);
          deletedCount++;
        }
      }
    }

    final fuelRecordsAfter = await fuelStore.find(db);
    print('Fuel logs after dedup: ${fuelRecordsAfter.length} (deleted $deletedCount)');

    // Check service records
    final serviceRecords = await serviceStore.find(db);
    print('Service records: ${serviceRecords.length}');
  } finally {
    await db.close();
  }
}
