import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'custom_widgets.dart';
import 'transaction_model.dart';
import 'api_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  // Chart Data State
  List<double> _monthlySpendData = List.filled(6, 0.0);
  List<double> _quarterlyDrivenData = List.filled(4, 0.0);
  List<double> _recentMileageData = [];
  List<String> _recentMileageLabels = [];
  double _totalFuelSpent = 0.0;
  DateTime? _totalFuelSince;

  // Labels
  List<String> _monthLabels = [];

  @override
  void initState() {
    super.initState();
    _fetchAndProcessData();
  }

  Future<void> _fetchAndProcessData({bool showSnackbar = false}) async {
    try {
      // 1. Fetch Raw Data
      List<FuelLog> logs = await _apiService.getFuelLogs();

      // 2. Sort by odometer and assign indexes
      logs.sort((a, b) => a.odometer.compareTo(b.odometer));
      for (int i = 0; i < logs.length; i++) {
        logs[i] = FuelLog(
          date: logs[i].date,
          odometer: logs[i].odometer,
          liters: logs[i].liters,
          cost: logs[i].cost,
          isFull: logs[i].isFull,
          tag: logs[i].tag,
          index: i,
        );
      }

      // 3. Sort by index for calculations
      logs.sort((a, b) => a.index.compareTo(b.index));

      // 4. If we have data, use the latest year present to aggregate monthly/quarterly
      if (logs.isNotEmpty) {
        final latestYear = logs.last.date.year;
        _calculateMonthlySpend(logs, year: latestYear);
        _calculateQuarterlyDriven(logs, year: latestYear);
        _calculateMileage(logs);
        _calculateTotalFuelSpent(logs);

        if (showSnackbar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Loaded ${logs.length} logs for $latestYear')));
        }
      } else {
        // No data available from API — provide demo/sample data so charts are visible
        _monthlySpendData = [
          150,
          140,
          160,
          150,
          140,
          150,
          160,
          150,
          140,
          150,
          140,
          150
        ];
        _quarterlyDrivenData = [2500, 2800, 3000, 3100];
        _recentMileageData = [15.0, 14.8, 15.2, 14.5, 15.0];
        _recentMileageLabels = [
          'R1\n15.0',
          'R2\n14.8',
          'R3\n15.2',
          'R4\n14.5',
          'R5\n15.0'
        ];

        if (showSnackbar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No logs found in the API')));
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
      if (mounted) setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading analytics: $e')));
    }
  }

  void _calculateMonthlySpend(List<FuelLog> logs, {int? year}) {
    // Get current date and calculate 6 months ago
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);

    // Filter logs from last 6 months and create month labels
    final recentLogs =
        logs.where((log) => log.date.isAfter(sixMonthsAgo)).toList();

    // Create data array for 6 months
    var spend = List.filled(6, 0.0);
    var monthLabels = <String>[];

    // Generate labels for last 6 months
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      monthLabels.add(DateFormat('MMM').format(date));
    }

    // Aggregate spending by month in the last 6 months
    for (var log in recentLogs) {
      final monthDiff =
          (now.year - log.date.year) * 12 + (now.month - log.date.month);
      if (monthDiff >= 0 && monthDiff < 6) {
        final index = 5 - monthDiff;
        spend[index] += log.cost;
      }
    }

    _monthlySpendData = spend;
    _monthLabels = monthLabels;
  }

  void _calculateQuarterlyDriven(List<FuelLog> logs, {int? year}) {
    var driven = List.filled(4, 0.0);
    final int targetYear = year ?? logs.last.date.year;

    // We need at least 2 logs to calculate distance
    for (int i = 1; i < logs.length; i++) {
      FuelLog current = logs[i];
      FuelLog previous = logs[i - 1];

      // Calculate distance driven between these two fills
      int distance = current.odometer - previous.odometer;

      // Attribute the distance to the quarter of the current fill date if it's in the target year
      if (current.date.year == targetYear && distance > 0) {
        int quarter = ((current.date.month - 1) / 3).floor(); // 0=Q1, 1=Q2...
        driven[quarter] += distance.toDouble();
      }
    }
    _quarterlyDrivenData = driven;
  }

  void _calculateMileage(List<FuelLog> logs) {
    List<double> efficiency = [];
    List<String> labels = [];

    // We need at least 2 logs to calculate mileage.
    // We iterate from the 2nd log.
    for (int i = 1; i < logs.length; i++) {
      FuelLog current = logs[i];
      FuelLog previous = logs[i - 1];

      int distance = current.odometer - previous.odometer;

      // Avoid division by zero and ensure positive distance
      if (current.liters > 0 && distance > 0) {
        double mileage = distance / current.liters;
        efficiency.add(mileage);
        labels.add(
            "${DateFormat('dd/MM').format(current.date)}\n${mileage.toStringAsFixed(1)}");
      }
    }

    // Keep only last 5 for the chart
    if (efficiency.length > 5) {
      _recentMileageData = efficiency.sublist(efficiency.length - 5);
      _recentMileageLabels = labels.sublist(labels.length - 5);
    } else {
      _recentMileageData = efficiency;
      _recentMileageLabels = labels;
    }
  }

  void _calculateTotalFuelSpent(List<FuelLog> logs) {
    double totalSpent = 0.0;
    for (var log in logs) {
      totalSpent += log.cost;
    }
    _totalFuelSpent = totalSpent;
    if (logs.isNotEmpty) {
      // logs are expected to be sorted by odometer ascending; oldest is first
      _totalFuelSince = logs.first.date;
    } else {
      _totalFuelSince = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title:
            const Text("Fuel Analysis", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh data',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _onRefresh(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download, color: Colors.white),
            onSelected: (value) => _handleExport(value),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                  value: 'fuel_json', child: Text('Export Fuel (JSON)')),
              const PopupMenuItem(
                  value: 'fuel_csv', child: Text('Export Fuel (CSV)')),
              const PopupMenuItem(
                  value: 'service_json', child: Text('Export Service (JSON)')),
              const PopupMenuItem(
                  value: 'service_csv', child: Text('Export Service (CSV)')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Total Spent on Fuel
                    const Text("Total Spent on Fuel",
                        style: TextStyle(
                            color: kTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    CustomCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Total Fuel Cost",
                                    style: TextStyle(
                                        color: kSubTextColor, fontSize: 14)),
                                if (_totalFuelSince != null)
                                  Text(
                                    'Since ${DateFormat('dd MMM yyyy').format(_totalFuelSince!)}',
                                    style: const TextStyle(
                                        color: kSubTextColor, fontSize: 12),
                                  ),
                              ],
                            ),
                            Text(
                              "₹${_totalFuelSpent.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  color: kPrimaryColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 2. Monthly Spend
                    const Text("Monthly Fuel Spend (Last 6 Months)",
                        style: TextStyle(
                            color: kTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    CustomCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BarChart(
                            dataPoints: _monthlySpendData,
                            labels: _monthLabels,
                            height: 200,
                          ),
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.center,
                            child: Text('Showing data for the last 6 months',
                                style: TextStyle(
                                    color: kSubTextColor, fontSize: 10)),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 3. Vehicle Driven (Quarterly)
                    const Text("Vehicle Driven (Quarterly - This Year)",
                        style: TextStyle(
                            color: kTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    CustomCard(
                      child: Column(
                        children: [
                          GradientLineChart(
                              dataPoints: _quarterlyDrivenData, height: 100),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildQLabel("Q1", _quarterlyDrivenData[0]),
                              _buildQLabel("Q2", _quarterlyDrivenData[1]),
                              _buildQLabel("Q3", _quarterlyDrivenData[2]),
                              _buildQLabel("Q4", _quarterlyDrivenData[3]),
                            ],
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 4. Recent Mileage
                    const Text("Mileage (Last 5 Refuels)",
                        style: TextStyle(
                            color: kTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    CustomCard(
                      child: Column(
                        children: [
                          _recentMileageData.isNotEmpty
                              ? GradientLineChart(
                                  dataPoints: _recentMileageData, height: 80)
                              : const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text("Not enough data",
                                      style: TextStyle(color: Colors.grey))),

                          const SizedBox(height: 10),

                          // Dynamic Labels Row - make labels align under points
                          Row(
                            children: _recentMileageLabels.map((label) {
                              return Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                      color: kSubTextColor, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }).toList(),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _onRefresh() async {
    if (mounted) setState(() => _isLoading = true);
    await _fetchAndProcessData(showSnackbar: true);
  }

  Future<void> _handleExport(String type) async {
    try {
      String? path;
      String message;

      switch (type) {
        case 'fuel_json':
          path = await _apiService.exportFuelLogsAsJson();
          message = 'Fuel logs exported to:\n$path';
          break;
        case 'fuel_csv':
          path = await _apiService.exportFuelLogsAsCsv();
          message = 'Fuel logs exported to:\n$path';
          break;
        case 'service_json':
          path = await _apiService.exportServiceRecordsAsJson();
          message = 'Service records exported to:\n$path';
          break;
        case 'service_csv':
          path = await _apiService.exportServiceRecordsAsCsv();
          message = 'Service records exported to:\n$path';
          break;
        default:
          message = 'Unknown export type';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildQLabel(String label, double value) {
    final display = value > 0 ? '${value.toInt()}km' : '-';
    return Text("$label: $display",
        style: const TextStyle(color: kSubTextColor, fontSize: 12));
  }
}
