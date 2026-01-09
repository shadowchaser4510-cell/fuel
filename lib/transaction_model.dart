class FuelLog {
  final DateTime date;
  final int odometer;
  final double liters;
  final double cost;
  final bool isFull;

  FuelLog({
    required this.date,
    required this.odometer,
    required this.liters,
    required this.cost,
    required this.isFull,
  });

  // Flexible factory that accepts either a list (row-based) or a map (keyed JSON)
  factory FuelLog.fromJson(dynamic json) {
    // Row format: [Date, Odometer, Liters, Cost, FullTank]
    if (json is List) {
      return FuelLog(
        date: DateTime.parse(json[0].toString()),
        odometer: int.parse(json[1].toString()),
        liters: double.parse(json[2].toString()),
        cost: double.parse(json[3].toString()),
        isFull: json[4].toString().toLowerCase() == 'true',
      );
    }

    // Map format: { 'date': ..., 'odometer': ..., ... }
    if (json is Map) {
      final dateVal = json['date'] ?? json['Date'] ?? json['timestamp'] ?? json['Timestamp'];
      final odometerVal = json['odometer'] ?? json['Odometer'] ?? json['odometer_km'];
      final litersVal = json['liters'] ?? json['Liters'] ?? json['fuel_liters'];
      final costVal = json['cost'] ?? json['Cost'] ?? json['amount'];
      final isFullVal = json['isFull'] ?? json['is_full'] ?? json['FullTank'];

      return FuelLog(
        date: DateTime.parse(dateVal.toString()),
        odometer: int.parse(odometerVal.toString()),
        liters: double.parse(litersVal.toString()),
        cost: double.parse(costVal.toString()),
        isFull: isFullVal.toString().toLowerCase() == 'true',
      );
    }

    throw Exception('Unsupported FuelLog json format: ${json.runtimeType}');
  }

  // Method to convert FuelLog to JSON (for sending to Google Sheets)
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'odometer': odometer,
      'liters': liters,
      'cost': cost,
      'isFull': isFull,
    };
  }
}

class ServiceRecord {
  final DateTime date;
  final int odometer;
  final double cost;

  ServiceRecord({
    required this.date,
    required this.odometer,
    required this.cost,
  });

  factory ServiceRecord.fromJson(dynamic json) {
    if (json is Map) {
      return ServiceRecord(
        date: DateTime.parse(json['date'] ?? json['Date'] ?? ''),
        odometer: int.parse(json['odometer']?.toString() ?? json['Odometer']?.toString() ?? '0'),
        cost: double.parse(json['cost']?.toString() ?? json['Cost']?.toString() ?? '0'),
      );
    }
    throw Exception('Unsupported ServiceRecord json format: ${json.runtimeType}');
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'odometer': odometer,
      'cost': cost,
    };
  }
}