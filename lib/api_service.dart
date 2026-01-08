import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'transaction_model.dart';

class ApiService {
  // Local-only service: reads/writes from Hive box 'fuel_logs'

  Future<List<FuelLog>> getFuelLogs() async {
    try {
      final box = Hive.isBoxOpen('fuel_logs') ? Hive.box('fuel_logs') : await Hive.openBox('fuel_logs');
      final List<FuelLog> local = box.values.map((e) {
        try {
          return FuelLog.fromJson(e);
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
      final box = Hive.isBoxOpen('fuel_logs') ? Hive.box('fuel_logs') : await Hive.openBox('fuel_logs');
      await box.add(log.toJson());
      debugPrint('Saved log locally to Hive');
      return true;
    } catch (e) {
      throw Exception('Error saving to local storage: $e');
    }
  }
}
