#!/bin/bash

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  App Reset Script"
echo "  (Forces iOS to reload Info.plist)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Clean build
echo "1️⃣  Cleaning build folder..."
cd /Users/jandrebadenhorst/Projects/logbook
rm -rf ~/Library/Developer/Xcode/DerivedData/logbook-*
echo "   ✅ Build cache cleared"
echo ""

# Get booted simulator
SIMULATOR_ID=$(xcrun simctl list devices | grep "Booted" | grep -oE '[0-9A-F-]{36}' | head -1)

if [ -z "$SIMULATOR_ID" ]; then
    echo "⚠️  No simulator is currently booted."
    echo "   Please start a simulator first, then run this script again."
    echo ""
    exit 1
fi

echo "2️⃣  Found booted simulator: $SIMULATOR_ID"
echo ""

# Uninstall app
echo "3️⃣  Uninstalling Logbook from simulator..."
xcrun simctl uninstall "$SIMULATOR_ID" com.personal.logbook 2>/dev/null
echo "   ✅ App uninstalled"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Reset Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. In Xcode, press ⌘R to run the app"
echo "  2. Once app launches, check Settings → Logbook"
echo "  3. You should now see the 'Live Activities' toggle!"
echo ""
echo "If testing on a physical device:"
echo "  - Long-press the Logbook app icon"
echo "  - Tap 'Remove App' → 'Delete App'"
echo "  - Then run from Xcode (⌘R)"
echo ""
