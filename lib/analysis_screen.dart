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
  List<double> _monthlySpendData = List.filled(12, 0.0);
  List<double> _quarterlyDrivenData = List.filled(4, 0.0);
  List<double> _recentMileageData = [];
  List<String> _recentMileageLabels = [];
  
  // Labels
  final List<String> _monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    _fetchAndProcessData();
  }

  Future<void> _fetchAndProcessData({bool showSnackbar = false}) async {
    try {
      // 1. Fetch Raw Data
      List<FuelLog> logs = await _apiService.getFuelLogs();
      
      // 2. Sort by Date (Crucial for Odometer math)
      logs.sort((a, b) => a.date.compareTo(b.date));

      // 3. If we have data, use the latest year present to aggregate monthly/quarterly
      if (logs.isNotEmpty) {
        final latestYear = logs.last.date.year;
        _calculateMonthlySpend(logs, year: latestYear);
        _calculateQuarterlyDriven(logs, year: latestYear);
        _calculateMileage(logs);

        if (showSnackbar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded ${logs.length} logs for $latestYear')));
        }
      } else {
        // No data available from API — provide demo/sample data so charts are visible
        _monthlySpendData = [150, 140, 160, 150, 140, 150, 160, 150, 140, 150, 140, 150];
        _quarterlyDrivenData = [2500, 2800, 3000, 3100];
        _recentMileageData = [15.0, 14.8, 15.2, 14.5, 15.0];
        _recentMileageLabels = ['R1\n15.0', 'R2\n14.8', 'R3\n15.2', 'R4\n14.5', 'R5\n15.0'];

        if (showSnackbar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No logs found in the API')));
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
    }
  }

  void _calculateMonthlySpend(List<FuelLog> logs, {int? year}) {
    // Reset data
    var spend = List.filled(12, 0.0);
    final int targetYear = year ?? logs.last.date.year;

    for (var log in logs) {
      // Filter for the target year
      if (log.date.year == targetYear) {
        // Month is 1-based (1=Jan), so subtract 1 for index
        int monthIndex = log.date.month - 1;
        spend[monthIndex] += log.cost;
      }
    }
    _monthlySpendData = spend;
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
        labels.add("${DateFormat('dd/MM').format(current.date)}\n${mileage.toStringAsFixed(1)}");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title: const Text("Fuel Analysis", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh data',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _onRefresh(),
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
                  // 1. Monthly Spend
                  const Text("Monthly Fuel Spend (This Year)", style: TextStyle(color: kTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                          CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BarChart(
                          dataPoints: _monthlySpendData, 
                          labels: _monthLabels,
                          height: 180,
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('Showing data for the latest year present in Google Sheets', style: TextStyle(color: kSubTextColor, fontSize: 10)),
                        )
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 25),

                  // 2. Vehicle Driven (Quarterly)
                  const Text("Vehicle Driven (Quarterly - This Year)", style: TextStyle(color: kTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  CustomCard(
                    child: Column(
                      children: [
                        GradientLineChart(dataPoints: _quarterlyDrivenData, height: 100),
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

                  // 3. Recent Mileage
                  const Text("Mileage (Last 5 Refuels)", style: TextStyle(color: kTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  CustomCard(
                    child: Column(
                      children: [
                        _recentMileageData.isNotEmpty 
                        ? GradientLineChart(dataPoints: _recentMileageData, height: 80)
                        : const Padding(padding: EdgeInsets.all(20), child: Text("Not enough data", style: TextStyle(color: Colors.grey))),
                        
                        const SizedBox(height: 10),
                        
                        // Dynamic Labels Row - make labels align under points
                        Row(
                          children: _recentMileageLabels.map((label) {
                            return Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(color: kSubTextColor, fontSize: 10),
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

  Widget _buildQLabel(String label, double value) {
    final display = value > 0 ? '${value.toInt()}km' : '-';
    return Text(
      "$label: $display", 
      style: const TextStyle(color: kSubTextColor, fontSize: 12)
    );
  }
}