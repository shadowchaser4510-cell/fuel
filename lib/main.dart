import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'custom_widgets.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive_adapters/fuel_log_adapter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer existing project-local .hive_data directory (created by migration)
  final hiveDir = Directory('${Directory.current.path}/.hive_data');
  if (await hiveDir.exists()) {
    Hive.init(hiveDir.path);
  } else {
    await Hive.initFlutter();
  }

  Hive.registerAdapter(FuelLogAdapter());
  await Hive.openBox('fuel_logs');

  runApp(const FuelTrackerApp());
}

class FuelTrackerApp extends StatelessWidget {
  const FuelTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fuel Tracker',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackgroundColor,
        primaryColor: kPrimaryColor,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
          surface: kCardColor,
          onSurface: kTextColor,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationWrapper(),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openLogRefuelingSheet() async {
    // This can be called from the Bottom Navigation Bar's '+' button
    // For now, the HomeScreen's '+' button handles this.
    // You can implement similar logic here if you want the bottom nav button to work globally.
    debugPrint("Add button tapped from bottom nav");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(onNavigateToAnalysis: () => _onItemTapped(1)),
          const AnalysisScreen(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        onAddTapped: _openLogRefuelingSheet,
      ),
    );
  }
}
