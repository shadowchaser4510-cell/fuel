import 'package:hive/hive.dart';
import '../transaction_model.dart';

class FuelLogAdapter extends TypeAdapter<FuelLog> {
  @override
  final int typeId = 0;

  @override
  FuelLog read(BinaryReader reader) {
    final map = Map<String, dynamic>.from(reader.readMap());
    return FuelLog(
      date: DateTime.parse(map['date'] as String),
      odometer: (map['odometer'] as num).toInt(),
      liters: (map['liters'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
      isFull: map['isFull'] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FuelLog obj) {
    writer.writeMap(obj.toJson());
  }
}
