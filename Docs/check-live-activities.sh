#!/bin/bash

# Live Activities Diagnostic Script
# Run this to check your Live Activities setup

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Live Activities Setup Diagnostics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PROJECT_DIR="/Users/jandrebadenhorst/Projects/logbook"
cd "$PROJECT_DIR" || exit 1

PASS="✅"
FAIL="❌"
WARN="⚠️"

# Check 1: NSSupportsLiveActivities in build settings
echo "1️⃣  Checking NSSupportsLiveActivities in build settings..."
if grep -q "INFOPLIST_KEY_NSSupportsLiveActivities = YES" logbook.xcodeproj/project.pbxproj; then
    echo "   $PASS NSSupportsLiveActivities is enabled"
else
    echo "   $FAIL NSSupportsLiveActivities NOT found in build settings"
    echo "      This MUST be set to YES for Live Activities to work"
fi
echo ""

# Check 2: TripLiveActivityAttributes in main app
echo "2️⃣  Checking TripLiveActivityAttributes (main app)..."
if [ -f "logbook/Models/TripLiveActivityAttributes.swift" ]; then
    echo "   $PASS Main app copy exists"
else
    echo "   $FAIL Main app copy MISSING"
    echo "      Expected: logbook/Models/TripLiveActivityAttributes.swift"
fi
echo ""

# Check 3: TripLiveActivityAttributes in widget extension
echo "3️⃣  Checking TripLiveActivityAttributes (widget extension)..."
if [ -f "logbookwidget/TripLiveActivityAttributes.swift" ]; then
    echo "   $PASS Widget extension copy exists"
else
    echo "   $FAIL Widget extension copy MISSING"
    echo "      Expected: logbookwidget/TripLiveActivityAttributes.swift"
    echo "      Fix: cp logbook/Models/TripLiveActivityAttributes.swift logbookwidget/"
fi
echo ""

# Check 4: TripLiveActivity widget implementation
echo "4️⃣  Checking TripLiveActivity widget implementation..."
if [ -f "logbookwidget/TripLiveActivity.swift" ]; then
    echo "   $PASS Widget implementation exists"
else
    echo "   $FAIL Widget implementation MISSING"
    echo "      Expected: logbookwidget/TripLiveActivity.swift"
fi
echo ""

# Check 5: ActivityKit import in TripTrackingService
echo "5️⃣  Checking ActivityKit integration..."
if grep -q "import ActivityKit" logbook/Services/TripTrackingService.swift; then
    echo "   $PASS ActivityKit imported in TripTrackingService"
else
    echo "   $FAIL ActivityKit not imported"
fi

if grep -q "startLiveActivity" logbook/Services/TripTrackingService.swift; then
    echo "   $PASS startLiveActivity() method exists"
else
    echo "   $FAIL startLiveActivity() method not found"
fi
echo ""

# Check 6: Widget bundle configuration
echo "6️⃣  Checking widget bundle configuration..."
if grep -q "TripLiveActivity()" logbookwidget/logbookwidgetBundle.swift; then
    echo "   $PASS TripLiveActivity registered in widget bundle"
else
    echo "   $FAIL TripLiveActivity NOT registered in bundle"
fi
echo ""

# Check 7: Deep link handler
echo "7️⃣  Checking deep link handler..."
if grep -q "onOpenURL" logbook/logbookApp.swift; then
    echo "   $PASS Deep link handler (.onOpenURL) exists"
else
    echo "   $FAIL Deep link handler missing"
fi

if grep -q "logbook://stopTrip" logbook/logbookApp.swift; then
    echo "   $PASS stopTrip deep link configured"
else
    echo "   $WARN stopTrip deep link not found"
fi
echo ""

# Check 8: Location permissions
echo "8️⃣  Checking location permissions..."
if grep -q "NSLocationAlwaysAndWhenInUseUsageDescription" logbook.xcodeproj/project.pbxproj; then
    echo "   $PASS Location permissions configured"
else
    echo "   $FAIL Location permissions NOT configured"
fi
echo ""

# Check 9: Background modes
echo "9️⃣  Checking background modes..."
if grep -q "INFOPLIST_KEY_UIBackgroundModes = location" logbook.xcodeproj/project.pbxproj; then
    echo "   $PASS Background location mode enabled"
else
    echo "   $FAIL Background location mode NOT enabled"
fi
echo ""

# Check 10: Build success
echo "🔟 Checking if project builds..."
echo "   (This may take a moment...)"
if xcodebuild -project logbook.xcodeproj -scheme logbook -destination 'generic/platform=iOS' build > /tmp/logbook_build.log 2>&1; then
    echo "   $PASS Project builds successfully"
else
    echo "   $FAIL Build failed - check /tmp/logbook_build.log for errors"
    echo "      Last few errors:"
    tail -20 /tmp/logbook_build.log | grep "error:"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Diagnostics Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo ""
echo "If all checks show $PASS, your Live Activities setup is correct!"
echo ""
echo "If you see any $FAIL:"
echo "  1. Read the message below each failed check"
echo "  2. Follow the suggested fix"
echo "  3. Run this script again to verify"
echo ""
echo "Next steps:"
echo "  1. Open Xcode"
echo "  2. Select 'logbook' scheme (NOT logbookwidgetExtension)"
echo "  3. Run the app (⌘R)"
echo "  4. Start a trip and watch the Xcode console for Live Activity logs"
echo ""
echo "For detailed troubleshooting, see:"
echo "  📖 XCODE_TROUBLESHOOTING.md"
echo "  📖 LIVE_ACTIVITIES_IMPLEMENTATION.md"
echo ""
