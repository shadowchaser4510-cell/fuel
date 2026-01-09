import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:ui' as ui;
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

  // Car image guard
  Uint8List? _carImageBytes;
  bool _carImageLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadCarImage();
  }

  Future<void> _fetchData() async {
    try {
      final logs = await _apiService.getFuelLogs();
      // Sort by odometer to assign indexes
      logs.sort((a, b) => a.odometer.compareTo(b.odometer));
      
      // Assign indexes based on odometer reading
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
      
      // Sort by index for calculations
      logs.sort((a, b) => a.index.compareTo(b.index));

      setState(() {
        _fuelLogs = logs;
        _isLoading = false;
        _calculateSummaryData();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Error fetching data: $e");
    }
  }

  void _calculateSummaryData() {
    if (_fuelLogs.isEmpty) {
      _daysSinceLastRefuel = "N/A";
      _lastMileage = "N/A";
      return;
    }
    // 1. Days since last refuel
    final lastLog = _fuelLogs.last;
    final difference = DateTime.now().difference(lastLog.date).inDays;
    _daysSinceLastRefuel = "$difference days ago";

    // 2. Last Mileage — show the mileage (km per litre) for the latest refuel if possible,
    //    and the rupees/km for the last refuel as additional info.
    if (_fuelLogs.length >= 2) {
      final prevLog = _fuelLogs[_fuelLogs.length - 2];
      final distance = lastLog.odometer - prevLog.odometer;
      if (distance > 0 && lastLog.liters > 0) {
        final mileage = distance / lastLog.liters;
        final rupeesPerKm = lastLog.cost / distance;
        _lastMileage = "${mileage.toStringAsFixed(1)} km/L\n₹${rupeesPerKm.toStringAsFixed(2)}/km";
      } else {
        // Fallback to odometer if we cannot compute mileage
        _lastMileage = "${lastLog.odometer} km";
      }
    } else {
      // Not enough data to compute mileage — show odometer reading
      _lastMileage = "${lastLog.odometer} km";
    }
  }

  Future<void> _loadCarImage() async {
    const url =
        'https://cdni.autocarindia.com/Utils/ImageResizer.ashx?n=https://cdni.autocarindia.com/ExtraImages/20230904011632_Nexon_facelift_front.jpg&w=700&c=1';
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        try {
          // Try to instantiate codec to ensure bytes are valid image data
          await ui.instantiateImageCodec(res.bodyBytes);
          if (mounted)
            setState(() {
              _carImageBytes = res.bodyBytes;
              _carImageLoading = false;
            });
          return;
        } catch (e) {
          debugPrint('Car image decode failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Car image fetch failed: $e');
    }

    if (mounted)
      setState(() {
        _carImageBytes = null;
        _carImageLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.7),
            radius: 1.2,
            colors: [Color(0xFF131313), Color(0xFF1F1F1F)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: kPrimaryColor))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // small status icon top-left
                        const Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0x33000000),
                              child: Icon(Icons.radio_button_checked,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),

                        // Top row: menu button (car title is shown in the large header below)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                                onPressed: () {},
                                icon:
                                    const Icon(Icons.menu, color: kTextColor)),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Large header
                        SizedBox(
                          height: 260,
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.only(left: 8.0, top: 12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            SizedBox(height: 8),
                                            Text("Tata Nexon",
                                                style: TextStyle(
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.bold,
                                                    color: kTextColor)),
                                            SizedBox(height: 6),
                                            Text("HR35W0241",
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: kSubTextColor)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Spacer(flex: 2),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 20,
                                bottom: 20,
                                width: MediaQuery.of(context).size.width * 0.62,
                                child: Container(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black54,
                                            blurRadius: 20,
                                            offset: Offset(0, 8))
                                      ]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child:
                                        Stack(fit: StackFit.expand, children: [
                                      if (_carImageLoading)
                                        const Center(
                                            child: CircularProgressIndicator(
                                                color: kPrimaryColor))
                                      else if (_carImageBytes != null)
                                        Image.memory(
                                          _carImageBytes!,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.topRight,
                                        )
                                      else
                                        // Fallback placeholder when image failed to load
                                        Container(
                                          color: kCardColor,
                                          child: const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.directions_car,
                                                    size: 80,
                                                    color: kSubTextColor),
                                                SizedBox(height: 8),
                                                Text('Car image',
                                                    style: TextStyle(
                                                        color: kSubTextColor)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Positioned.fill(
                                          child: DecoratedBox(
                                              decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.black.withOpacity(0.55),
                                              Colors.transparent
                                            ],
                                            stops: const [
                                              0.0,
                                              0.45
                                            ]),
                                      ))),
                                    ]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Two tiles side by side: Last Refueling (1 number) and Last Mileage (2 numbers)
                        Row(
                          children: [
                            // Left tile: Last Refueling (flex 1)
                            Expanded(
                              flex: 1,
                              child: _buildSummaryCard(
                                  "Last Refueling", _daysSinceLastRefuel),
                            ),
                            const SizedBox(width: 15),
                            // Right tile: Last Mileage (flex 2)
                            Expanded(
                              flex: 2,
                              child: _buildMileageCard(_lastMileage),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        const Center(
                            child: Text('Tap the + button to log a refueling',
                                style: TextStyle(
                                    color: kSubTextColor, fontSize: 12))),

                        SizedBox(
                            height:
                                MediaQuery.of(context).padding.bottom + 140),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const LogRefuelingScreen(),
      ),
    );

    if (result == true) {
      // A new entry was added — refresh the list and recalculate summary
      await _fetchData();
    }
  }

  // Summary Card showing a large number and a small unit/label below
  Widget _buildSummaryCard(String title, String value) {
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  color: kSubTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              children: [
                Text(mainText,
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: kTextColor,
                        height: 1)),
                if (subText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(subText,
                      style: const TextStyle(
                          color: kSubTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMileageCard(String value) {
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
          mileageUnit = mileageParts.length > 1 ? mileageParts.sublist(1).join(' ') : 'km/L';
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('LAST MILEAGE',
              style: TextStyle(
                  color: kSubTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 16),
          // All three metrics in a row: km/L on left, rupees/km on right (with rupee symbol)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: km/L
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(mileageNum,
                          style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: kTextColor,
                              height: 1)),
                    ),
                    const SizedBox(height: 8),
                    Text(mileageUnit,
                        style: const TextStyle(
                            color: kSubTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // Right: ₹/km
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(rupeesNum,
                          style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: kTextColor,
                              height: 1)),
                    ),
                    const SizedBox(height: 8),
                    Text('${rupeesUnit}₹',
                        style: const TextStyle(
                            color: kSubTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
