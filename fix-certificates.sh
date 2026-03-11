#!/bin/bash

# Logbook App - Certificate Fix Script
# Run this if you're getting certificate verification errors on device

set -e

echo ""
echo "🔧 Logbook Certificate Fix Script"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "logbook.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: Run this script from the logbook project root directory${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Cleaning Xcode derived data...${NC}"
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo -e "${GREEN}✅ Derived data cleaned${NC}"
echo ""

echo -e "${YELLOW}Step 2: Cleaning provisioning profiles...${NC}"
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
echo -e "${GREEN}✅ Provisioning profiles cleaned${NC}"
echo ""

echo -e "${YELLOW}Step 3: Cleaning build artifacts...${NC}"
rm -rf .build
rm -rf build
echo -e "${GREEN}✅ Build artifacts cleaned${NC}"
echo ""

echo -e "${YELLOW}Step 4: Checking certificates...${NC}"
CERT_COUNT=$(security find-identity -v -p codesigning | grep "Apple Development" | wc -l)
if [ $CERT_COUNT -eq 0 ]; then
    echo -e "${RED}❌ No valid development certificates found!${NC}"
    echo ""
    echo "Please install a development certificate:"
    echo "1. Go to: https://developer.apple.com/account/resources/certificates/list"
    echo "2. Create a new iOS Development certificate"
    echo "3. Download and install it"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ Found $CERT_COUNT development certificate(s)${NC}"
    security find-identity -v -p codesigning | grep "Apple Development"
fi
echo ""

echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}Next steps in Xcode:${NC}"
echo ""
echo "1. Open logbook.xcodeproj in Xcode"
echo "2. Select the 'logbook' scheme (top left)"
echo "3. Select your device as the run destination"
echo "4. Go to Product → Clean Build Folder (⌘⇧K)"
echo "5. Go to Product → Build (⌘B)"
echo ""
echo -e "${YELLOW}If you see signing errors:${NC}"
echo ""
echo "A. Select 'logbook' target → Signing & Capabilities"
echo "   - Verify Team is set to BGU4626AR9"
echo "   - Click 'Try Again' if there's a warning"
echo ""
echo "B. Repeat for 'logbookwidgetExtension' target"
echo ""
echo "C. If still failing, you need to register App Groups:"
echo "   → https://developer.apple.com/account/resources/identifiers/list/applicationGroup"
echo "   → Create: group.com.personal.logbook"
echo ""
echo -e "${YELLOW}On your device:${NC}"
echo ""
echo "If you see 'Untrusted Developer' after installing:"
echo "  Settings → General → VPN & Device Management"
echo "  → Tap your developer certificate → Trust"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}For detailed troubleshooting, see:${NC}"
echo "  CERTIFICATE_TROUBLESHOOTING.md"
echo ""
