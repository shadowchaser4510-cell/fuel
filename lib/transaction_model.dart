class FuelLog {
  final DateTime date;
  final int odometer;
  final double liters;
  final double cost;
  final bool isFull;
  final String? tag; // Optional tag to name the refuel log
  final int index; // Index based on odometer reading for proper sorting

  FuelLog({
    required this.date,
    required this.odometer,
    required this.liters,
    required this.cost,
    required this.isFull,
    this.tag,
    this.index = 0,
  });

  // Flexible factory that accepts either a list (row-based) or a map (keyed JSON)
  factory FuelLog.fromJson(dynamic json) {
    // Row format: [Date, Odometer, Liters, Cost, FullTank, Tag]
    if (json is List) {
      return FuelLog(
        date: DateTime.parse(json[0].toString()),
        odometer: int.parse(json[1].toString()),
        liters: double.parse(json[2].toString()),
        cost: double.parse(json[3].toString()),
        isFull: json[4].toString().toLowerCase() == 'true',
        tag: json.length > 5 && json[5]?.toString().isNotEmpty == true ? json[5].toString() : null,
        index: json.length > 6 ? int.parse(json[6].toString()) : 0,
      );
    }

    // Map format: { 'date': ..., 'odometer': ..., ... }
    if (json is Map) {
      final dateVal = json['date'] ??
          json['Date'] ??
          json['timestamp'] ??
          json['Timestamp'];
      final odometerVal =
          json['odometer'] ?? json['Odometer'] ?? json['odometer_km'];
      final litersVal = json['liters'] ?? json['Liters'] ?? json['fuel_liters'];
      final costVal = json['cost'] ?? json['Cost'] ?? json['amount'];
      final isFullVal = json['isFull'] ?? json['is_full'] ?? json['FullTank'];
      final tagVal = json['tag'] ?? json['Tag'];
      final indexVal = json['index'] ?? json['Index'] ?? 0;

      return FuelLog(
        date: DateTime.parse(dateVal.toString()),
        odometer: int.parse(odometerVal.toString()),
        liters: double.parse(litersVal.toString()),
        cost: double.parse(costVal.toString()),
        isFull: isFullVal.toString().toLowerCase() == 'true',
        tag: tagVal?.toString().isNotEmpty == true ? tagVal.toString() : null,
        index: int.parse(indexVal.toString()),
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
      'tag': tag,
      'index': index,
    };
  }
}

class ServiceRecord {
  final DateTime date;
  final int odometer;
  final double cost;
  final int index; // Index based on odometer reading for proper sorting

  ServiceRecord({
    required this.date,
    required this.odometer,
    required this.cost,
    this.index = 0,
  });

  factory ServiceRecord.fromJson(dynamic json) {
    if (json is Map) {
      return ServiceRecord(
        date: DateTime.parse(json['date'] ?? json['Date'] ?? ''),
        odometer: int.parse(json['odometer']?.toString() ??
            json['Odometer']?.toString() ??
            '0'),
        cost: double.parse(
            json['cost']?.toString() ?? json['Cost']?.toString() ?? '0'),
        index: int.parse(json['index']?.toString() ?? json['Index']?.toString() ?? '0'),
      );
    }
    throw Exception(
        'Unsupported ServiceRecord json format: ${json.runtimeType}');
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'odometer': odometer,
      'cost': cost,
      'index': index,
    };
  }
}
