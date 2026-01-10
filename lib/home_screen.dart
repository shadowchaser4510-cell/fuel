import 'package:flutter/material.dart';
import 'custom_widgets.dart';
import 'transaction_model.dart';
import 'api_service.dart';
import 'log_refueling_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToAnalysis;

  const HomeScreen({super.key, required this.onNavigateToAnalysis});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<FuelLog> _fuelLogs = [];
  bool _isLoading = true;

  String _daysSinceLastRefuel = "N/A";
  String _lastMileage = "N/A";

  final String _carImageUrl =
      'https://cdni.autocarindia.com/Utils/ImageResizer.ashx?n=https://cdni.autocarindia.com/ExtraImages/20230904011632_Nexon_facelift_front.jpg&w=700&c=1';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final logs = await _apiService.getFuelLogs();
      logs.sort((a, b) => a.odometer.compareTo(b.odometer));

      setState(() {
        _fuelLogs = logs;
        _isLoading = false;
        _calculateSummaryData();
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching data: $e");
    }
  }

  void _calculateSummaryData() {
    if (_fuelLogs.isEmpty) {
      _daysSinceLastRefuel = "N/A";
      _lastMileage = "N/A";
      return;
    }

    final lastLog = _fuelLogs.last;
    final difference = DateTime.now().difference(lastLog.date).inDays;
    _daysSinceLastRefuel = difference == 0 ? "Today" : "$difference days ago";

    if (_fuelLogs.length >= 2) {
      final prevLog = _fuelLogs[_fuelLogs.length - 2];
      final distance = lastLog.odometer - prevLog.odometer;

      if (distance > 0 && lastLog.liters > 0) {
        final mileage = distance / lastLog.liters;
        final rupeesPerKm = lastLog.cost / distance;
        // Capitalized Km here as requested
        _lastMileage =
            "${mileage.toStringAsFixed(2)} Km/L\n₹${rupeesPerKm.toStringAsFixed(2)}/km";
      } else {
        _lastMileage = "N/A";
      }
    } else {
      _lastMileage = "N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: kPrimaryColor))
            : RefreshIndicator(
                onRefresh: _fetchData,
                color: kPrimaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // CHANGED: Text to "Welcome, Tushar"
                          const Text("Welcome, Tushar",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: kSubTextColor)),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.settings_outlined,
                                color: kTextColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- HERO CAR CARD ---
                      _buildHeroVehicleCard(),

                      // CHANGED: Increased spacing to reduce empty space at bottom
                      const SizedBox(height: 40),

                      // Stats Row
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _buildSummaryCard("Last Refueling",
                                _daysSinceLastRefuel, Icons.access_time_filled),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            flex: 5,
                            child: _buildMileageCard(
                                _lastMileage, Icons.speed_rounded),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // --- QUICK ACTION BANNER ---
                      _buildQuickActionBanner(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeroVehicleCard() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kCardColor,
                    kCardColor.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.directions_car_filled_outlined,
              size: 150,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          Positioned(
            top: 30,
            left: 25,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CHANGED: Removed "My Vehicle" text
                const Text("Tata Nexon",
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kTextColor,
                        letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: kPrimaryColor.withOpacity(0.3), width: 1),
                  ),
                  child: const Text("HR35W0241",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryColor)),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Image.network(
              _carImageUrl,
              height: 160,
              width: 220,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(height: 160, width: 220);
              },
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.broken_image,
                    size: 80, color: kSubTextColor.withOpacity(0.3));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBanner() {
    return GestureDetector(
      onTap: _openLogRefuelingSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPrimaryColor.withOpacity(0.15),
              kPrimaryColor.withOpacity(0.05)
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrimaryColor.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: kPrimaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Icon(Icons.local_gas_station_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Log New Refueling",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kTextColor)),
                SizedBox(height: 4),
                Text("Keep your stats up to date.",
                    style: TextStyle(fontSize: 14, color: kSubTextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    String mainText = value;
    String subText = '';
    if (value != 'N/A') {
      if (value.contains('\n')) {
        final parts = value.split('\n');
        mainText = parts.first;
        subText = parts.length > 1 ? parts[1] : '';
      } else if (title == 'Last Refueling' && value.contains(' ')) {
        final parts = value.split(' ');
        mainText = parts.first;
        subText = parts.sublist(1).join(' ');
      }
    }

    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kSubTextColor, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: kSubTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mainText,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: kTextColor,
                        height: 1.0)),
                if (subText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(subText,
                      style: const TextStyle(
                          color: kSubTextColor, // CHANGED: Same color as label
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMileageCard(String value, IconData icon) {
    String mileageNum = 'N/A';
    String mileageUnit = '';
    String rupeesNum = 'N/A';
    String rupeesUnit = '';

    if (value != 'N/A' && value.contains('\n')) {
      final parts = value.split('\n');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        final mileageParts = parts[0].split(' ');
        if (mileageParts.isNotEmpty) {
          mileageNum = mileageParts[0];
          mileageUnit = mileageParts.length > 1
              ? mileageParts.sublist(1).join(' ')
              : 'km/L';
        }
      }
      if (parts.length > 1 && parts[1].isNotEmpty) {
        final rupeesParts = parts[1].split('₹');
        if (rupeesParts.length > 1) {
          final amountAndUnit = rupeesParts[1].trim();
          final unitIndex = amountAndUnit.indexOf('/');
          if (unitIndex > 0) {
            rupeesNum = amountAndUnit.substring(0, unitIndex).trim();
            rupeesUnit = amountAndUnit.substring(unitIndex).trim();
          } else {
            rupeesNum = amountAndUnit;
          }
        }
      }
    } else if (value != 'N/A') {
      mileageNum = value;
    }

    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kSubTextColor, size: 18),
              const SizedBox(width: 8),
              const Text('Last Mileage',
                  style: TextStyle(
                      color: kSubTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mileage and Unit side-by-side
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(mileageNum,
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: kTextColor,
                              height: 1.0)),
                    ),
                    const SizedBox(width: 4),
                    Text(mileageUnit,
                        style: const TextStyle(
                            color: kSubTextColor, // CHANGED: Grey color
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                // Cost part centered below
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("₹$rupeesNum",
                          style: const TextStyle(
                              fontSize: 32, // CHANGED: Increased font size
                              fontWeight:
                                  FontWeight.w800, // CHANGED: Increased weight
                              color: kTextColor,
                              height: 1.0)),
                    ),
                    const SizedBox(width: 4),
                    // CHANGED: Fixed double slash issue
                    Text(rupeesUnit,
                        style: const TextStyle(
                            color: kSubTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openLogRefuelingSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LogRefuelingScreen(),
    );

    if (result == true) {
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Refueling logged successfully!'),
              backgroundColor: Colors.green),
        );
      }
    }
  }
}
