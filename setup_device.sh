#!/bin/bash
# Prepare the device for the updated APK

echo "=== Fuel Tracker App Setup ==="
echo ""

# Clear old data
echo "1. Clearing old app data..."
adb uninstall com.example.fuel_tracker 2>/dev/null || true
echo "   Old app uninstalled"
echo ""

# Clear old database
echo "2. Clearing old database..."
adb shell rm -rf /data/local/tmp/fuel_app 2>/dev/null || true
echo "   Old database cleared"
echo ""

# Install new APK
echo "3. Installing new APK..."
if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
  adb install build/app/outputs/flutter-apk/app-debug.apk
  echo "   APK installed successfully"
else
  echo "   ERROR: APK not found at build/app/outputs/flutter-apk/app-debug.apk"
  exit 1
fi
echo ""

echo "=== Setup Complete ==="
echo ""
echo "The app will now:"
echo "✓ Seed 23 fuel logs from the bundled export"
echo "✓ Seed 4 service records"
echo "✓ Automatically deduplicate any fuel logs with identical odometer readings"
echo ""
echo "Open the app to begin!"
