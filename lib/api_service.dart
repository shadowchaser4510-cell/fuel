import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sembast/sembast_io.dart';
import 'package:path/path.dart' as p;

import 'transaction_model.dart';

final _store = intMapStoreFactory.store('fuel_logs');
final _serviceStore = intMapStoreFactory.store('service_records');
Database? _db;

// Notifier to inform UI about fuel log changes so screens can refresh.
final ValueNotifier<int> fuelLogsVersion = ValueNotifier<int>(0);

// Map to track record keys for updates (stored as DateTime ISO string -> key)
final Map<String, int> _recordKeyCache = {};
final Map<String, int> _serviceKeyCache = {};

Future<Database> _getDb() async {
  if (_db != null) return _db!;
  // Use system temp directory which is writable on Android
  final dir = Directory(p.join(Directory.systemTemp.path, 'fuel_app', '.sembast_data'));
  if (!await dir.exists()) await dir.create(recursive: true);
  final dbPath = p.join(dir.path, 'fuel.db');
  _db = await databaseFactoryIo.openDatabase(dbPath);
  return _db!;
}

class ApiService {
  // Local-only service: reads/writes from sembast

  Future<List<FuelLog>> getFuelLogs() async {
    try {
      final db = await _getDb();
      final records = await _store.find(db);
      final List<FuelLog> local = records.map((r) {
        try {
          // Cache the key for later updates
          final json = Map<String, dynamic>.from(r.value);
          _recordKeyCache[json['date'] as String? ?? ''] = r.key;
          return FuelLog.fromJson(json);
        } catch (err) {
          debugPrint('Failed to parse local FuelLog: $err');
          return null;
        }
      }).whereType<FuelLog>().toList();
      return local;
    } catch (e) {
      throw Exception('Error reading local storage: $e');
    }
  }

  Future<bool> addFuelLog(FuelLog log) async {
    try {
      final db = await _getDb();
      await _store.add(db, log.toJson());
      fuelLogsVersion.value++;
      debugPrint('Saved log locally to sembast');
      return true;
    } catch (e) {
      throw Exception('Error saving to local storage: $e');
    }
  }

  Future<bool> updateFuelLog(FuelLog log) async {
    try {
      final db = await _getDb();
      // Find the record by date (unique identifier)
      final key = _recordKeyCache[log.date.toIso8601String()];
      if (key == null) {
        throw Exception('Log not found for update');
      }
      await _store.record(key).update(db, log.toJson());
      fuelLogsVersion.value++;
      debugPrint('Updated log in sembast');
      return true;
    } catch (e) {
      throw Exception('Error updating log: $e');
    }
  }

  Future<bool> deleteFuelLog(FuelLog log) async {
    try {
      final db = await _getDb();
      // Find the record by date (unique identifier)
      final key = _recordKeyCache[log.date.toIso8601String()];
      if (key == null) {
        throw Exception('Log not found for deletion');
      }
      await _store.record(key).delete(db);
      _recordKeyCache.remove(log.date.toIso8601String());
      fuelLogsVersion.value++;
      debugPrint('Deleted log from sembast');
      return true;
    } catch (e) {
      throw Exception('Error deleting log: $e');
    }
  }

  // Service Record Methods
  Future<List<ServiceRecord>> getServiceRecords() async {
    try {
      final db = await _getDb();
      final records = await _serviceStore.find(db);
      final List<ServiceRecord> services = records.map((r) {
        try {
          final json = Map<String, dynamic>.from(r.value);
          _serviceKeyCache[json['date'] as String? ?? ''] = r.key;
          return ServiceRecord.fromJson(json);
        } catch (err) {
          debugPrint('Failed to parse ServiceRecord: $err');
          return null;
        }
      }).whereType<ServiceRecord>().toList();
      return services;
    } catch (e) {
      throw Exception('Error reading service records: $e');
    }
  }

  Future<bool> addServiceRecord(ServiceRecord record) async {
    try {
      final db = await _getDb();
      await _serviceStore.add(db, record.toJson());
      debugPrint('Saved service record locally');
      return true;
    } catch (e) {
      throw Exception('Error saving service record: $e');
    }
  }

  Future<bool> updateServiceRecord(ServiceRecord record) async {
    try {
      final db = await _getDb();
      final key = _serviceKeyCache[record.date.toIso8601String()];
      if (key == null) {
        throw Exception('Service record not found for update');
      }
      await _serviceStore.record(key).update(db, record.toJson());
      debugPrint('Updated service record');
      return true;
    } catch (e) {
      throw Exception('Error updating service record: $e');
    }
  }

  Future<bool> deleteServiceRecord(ServiceRecord record) async {
    try {
      final db = await _getDb();
      final key = _serviceKeyCache[record.date.toIso8601String()];
      if (key == null) {
        throw Exception('Service record not found for deletion');
      }
      await _serviceStore.record(key).delete(db);
      _serviceKeyCache.remove(record.date.toIso8601String());
      debugPrint('Deleted service record');
      return true;
    } catch (e) {
      throw Exception('Error deleting service record: $e');
    }
  }

  // Deduplication: remove duplicate fuel logs with same odometer reading
  // Keeps the first one chronologically, deletes the rest
  Future<int> deduplicateFuelLogs() async {
    try {
      final db = await _getDb();
      final records = await _store.find(db);
      
      // Group logs by odometer
      final Map<int, List<RecordSnapshot>> byOdometer = {};
      for (final record in records) {
        final json = Map<String, dynamic>.from(record.value as Map);
        final odometer = json['odometer'] as int;
        byOdometer.putIfAbsent(odometer, () => []).add(record);
      }

      // For each odometer with duplicates, keep earliest date and delete rest
      int deletedCount = 0;
      for (final odometerGroup in byOdometer.values) {
        if (odometerGroup.length > 1) {
          // Sort by date
          odometerGroup.sort((a, b) {
            final jsonA = Map<String, dynamic>.from(a.value as Map);
            final jsonB = Map<String, dynamic>.from(b.value as Map);
            final dateA = DateTime.parse(jsonA['date'] as String);
            final dateB = DateTime.parse(jsonB['date'] as String);
            return dateA.compareTo(dateB);
          });
          
          // Delete all but the first
          for (int i = 1; i < odometerGroup.length; i++) {
            await _store.record(odometerGroup[i].key as int).delete(db);
            deletedCount++;
          }
        }
      }
      
      debugPrint('Deduplicated fuel logs: deleted $deletedCount duplicates');
      return deletedCount;
    } catch (e) {
      throw Exception('Error deduplicating fuel logs: $e');
    }
  }

  // Export fuel logs to JSON file (optional customDir for Downloads/Documents etc.)
  Future<String> exportFuelLogsAsJson({String? customDir}) async {
    try {
      final logs = await getFuelLogs();
      final jsonList = logs.map((log) => log.toJson()).toList();
      final jsonStr = json.encode(jsonList);
      
      final dirPath = customDir ?? p.join(Directory.systemTemp.path, 'fuel_app', 'exports');
      final dir = Directory(dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      final fileName = 'fuel_logs_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(jsonStr);
      debugPrint('Exported fuel logs to ${file.path}');
      return file.path;
    } catch (e) {
      throw Exception('Error exporting fuel logs: $e');
    }
  }

  // Export fuel logs to CSV file (optional customDir for Downloads/Documents etc.)
  Future<String> exportFuelLogsAsCsv({String? customDir}) async {
    try {
      final logs = await getFuelLogs();
      logs.sort((a, b) => a.date.compareTo(b.date));
      
      final buffer = StringBuffer();
      buffer.writeln('Date,Odometer (km),Liters,Cost,Full Tank');
      for (final log in logs) {
        buffer.writeln('${log.date.toIso8601String()},${log.odometer},${log.liters},${log.cost},${log.isFull}');
      }
      
      final dirPath = customDir ?? p.join(Directory.systemTemp.path, 'fuel_app', 'exports');
      final dir = Directory(dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      final fileName = 'fuel_logs_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(buffer.toString());
      debugPrint('Exported fuel logs to ${file.path}');
      return file.path;
    } catch (e) {
      throw Exception('Error exporting fuel logs: $e');
    }
  }

  // Export service records to JSON file (optional customDir for Downloads/Documents etc.)
  Future<String> exportServiceRecordsAsJson({String? customDir}) async {
    try {
      final records = await getServiceRecords();
      final jsonList = records.map((rec) => rec.toJson()).toList();
      final jsonStr = json.encode(jsonList);
      
      final dirPath = customDir ?? p.join(Directory.systemTemp.path, 'fuel_app', 'exports');
      final dir = Directory(dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      final fileName = 'service_records_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(jsonStr);
      debugPrint('Exported service records to ${file.path}');
      return file.path;
    } catch (e) {
      throw Exception('Error exporting service records: $e');
    }
  }

  // Export service records to CSV file (optional customDir for Downloads/Documents etc.)
  Future<String> exportServiceRecordsAsCsv({String? customDir}) async {
    try {
      final records = await getServiceRecords();
      records.sort((a, b) => a.date.compareTo(b.date));
      
      final buffer = StringBuffer();
      buffer.writeln('Date,Odometer (km),Cost (Rs)');
      for (final record in records) {
        buffer.writeln('${record.date.toIso8601String()},${record.odometer},${record.cost}');
      }
      
      final dirPath = customDir ?? p.join(Directory.systemTemp.path, 'fuel_app', 'exports');
      final dir = Directory(dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      
      final fileName = 'service_records_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsString(buffer.toString());
      debugPrint('Exported service records to ${file.path}');
      return file.path;
    } catch (e) {
      throw Exception('Error exporting service records: $e');
    }
  }

  // Import fuel logs from CSV file
  Future<int> importFuelLogsFromCsv(String csvContent) async {
    try {
      final db = await _getDb();

      final rows = csvContent.split('\n');
      if (rows.isEmpty) throw Exception('CSV file is empty');

      // Skip header row and process data rows
      int importedCount = 0;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i].trim();
        if (row.isEmpty) continue;

        final cells = row.split(',');
        if (cells.length < 4) continue; // Need at least: date, odometer, liters, cost

        try {
          final log = FuelLog(
            date: DateTime.parse(cells[0].trim()),
            odometer: int.parse(cells[1].trim()),
            liters: double.parse(cells[2].trim()),
            cost: double.parse(cells[3].trim()),
            isFull: cells.length > 4 ? (cells[4].trim().toLowerCase() == 'true') : false,
          );

          await _store.add(db, log.toJson());
          importedCount++;
        } catch (e) {
          debugPrint('Error parsing row $i: $e');
          continue;
        }
      }

      if (importedCount > 0) fuelLogsVersion.value = fuelLogsVersion.value + 1;
      return importedCount;
    } catch (e) {
      throw Exception('Error importing fuel logs: $e');
    }
  }
}
