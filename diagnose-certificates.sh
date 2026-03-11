#!/bin/bash

# Quick diagnostic to check what might be causing certificate issues

echo ""
echo "🔍 Logbook Certificate Diagnostic"
echo "=================================="
echo ""

# Check certificates
echo "📋 Installed Development Certificates:"
security find-identity -v -p codesigning | grep "Apple Development" || echo "❌ No development certificates found"
echo ""

# Check for expired certificates
echo "⏰ Checking for expired certificates..."
security find-identity -v -p codesigning | grep -i "expired" && echo "⚠️  Found expired certificates - revoke and create new ones" || echo "✅ No expired certificates"
echo ""

# Check provisioning profiles
echo "📦 Provisioning Profiles:"
PROFILE_COUNT=$(ls ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision 2>/dev/null | wc -l)
echo "Found $PROFILE_COUNT provisioning profile(s)"
echo ""

# Check if running on device
echo "🔌 Connected Devices:"
xcrun xctrace list devices 2>&1 | grep -v "Simulator" | grep -v "==" || echo "No devices connected"
echo ""

# Check Xcode version
echo "🛠️  Xcode Version:"
xcodebuild -version
echo ""

# Check project settings
echo "⚙️  Project Configuration:"
echo "  Bundle ID (main): com.personal.logbook"
echo "  Bundle ID (widget): com.personal.logbook.logbookwidget"
echo "  Team ID: BGU4626AR9"
echo "  App Group: group.com.personal.logbook"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  Common Issues & Fixes:"
echo ""
echo "1. 'Unable to verify app' on device"
echo "   → Settings → General → VPN & Device Management → Trust certificate"
echo ""
echo "2. 'No profiles for com.personal.logbook'"
echo "   → Register App ID at: https://developer.apple.com/account/resources/identifiers/list"
echo ""
echo "3. 'App Group not found'"
echo "   → Register at: https://developer.apple.com/account/resources/identifiers/list/applicationGroup"
echo "   → Create: group.com.personal.logbook"
echo ""
echo "4. 'Provisioning profile doesn't include app-groups'"
echo "   → Delete app from device"
echo "   → Xcode: Clean Build Folder (⌘⇧K)"
echo "   → Rebuild and reinstall"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 Full troubleshooting guide: CERTIFICATE_TROUBLESHOOTING.md"
echo ""
