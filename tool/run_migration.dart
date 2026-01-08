import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fuel_tracker/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final api = ApiService();
  try {
    final migrated = await api.migrateRemoteToLocal();
    print('Migration completed: $migrated rows cached into Hive');
  } catch (e) {
    print('Migration failed: $e');
  } finally {
    // Close boxes and exit
    await Hive.close();
  }
}
