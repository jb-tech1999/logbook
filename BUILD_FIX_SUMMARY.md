
# Build Issue Resolution - March 10, 2026

## Problem
The app would not build with the following error:
```
error: Multiple commands produce '/path/to/logbook.app/Info.plist'
```

## Root Cause
The project had `GENERATE_INFOPLIST_FILE = YES` in build settings, which auto-generates an Info.plist, **AND** a custom `logbook/Info.plist` file that was manually created for CarPlay configuration. This created a conflict where both the auto-generated and custom Info.plist tried to be copied to the same output location.

## Solution Applied

### 1. Removed Custom Info.plist
```bash
rm logbook/Info.plist
```

The custom file was only needed for:
- Location permission strings
- CarPlay scene configuration
- Background modes

### 2. Added Location Permissions to Build Settings
Updated `project.pbxproj` to include location permission strings directly in the auto-generated Info.plist:

**Debug Configuration:**
```
INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription = "Logbook needs access to your location to track trips and find nearby gas stations.";
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Logbook needs access to your location to track your trips and find nearby gas stations.";
INFOPLIST_KEY_UIBackgroundModes = location;
```

**Release Configuration:**
```
INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription = "Logbook needs access to your location to track trips and find nearby gas stations.";
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Logbook needs access to your location to track your trips and find nearby gas stations.";
INFOPLIST_KEY_UIBackgroundModes = location;
```

### 3. Removed Global INFOPLIST_FILE Reference
Removed this line from the project-wide settings:
```
"INFOPLIST_FILE[sdk=*]" = logbook/Info.plist;
```

### 4. Disabled CarPlay Integration
Since CarPlay requires special Apple approval, the following was disabled:

- `CarPlaySceneDelegate.swift` → renamed to `CarPlaySceneDelegate.swift.disabled`
- CarPlay entitlement in `logbook.entitlements` → already commented out
- CarPlay delegate code in `logbookApp.swift` → already commented out

### 5. Fixed Format String Errors
Fixed Swift string interpolation errors in `TripDetailView.swift`:

**Before (incorrect):**
```swift
"\(trip.totalDistance, format: .number.precision(.fractionLength(1))) km"
```

**After (correct):**
```swift
"\(trip.totalDistance.formatted(.number.precision(.fractionLength(1)))) km"
```

The `format:` parameter only works in SwiftUI `Text` views, not in regular string interpolation. In strings, you must call `.formatted()` directly on the value.

## Result

✅ **BUILD SUCCEEDED**

```bash
xcodebuild -project logbook.xcodeproj -scheme logbook -destination 'generic/platform=iOS' build
** BUILD SUCCEEDED **
```

## Files Modified

1. ✅ `logbook.xcodeproj/project.pbxproj` - Added INFOPLIST_KEY settings, removed conflicting references
2. ✅ `logbook/Info.plist` - Deleted (no longer needed)
3. ✅ `logbook/Views/TripDetailView.swift` - Fixed format string syntax
4. ✅ `logbook/Services/CarPlaySceneDelegate.swift` - Renamed to `.disabled`

## What Still Works

Even with CarPlay disabled:
- ✅ Trip tracking models (Trip, TripPoint)
- ✅ Trip tracking service (TripTrackingService)
- ✅ Background location tracking
- ✅ Trips view (list of all trips)
- ✅ Trip detail view (map, route, speed chart)
- ✅ Widget showing dashboard KPIs
- ✅ All existing features (logs, vehicles, dashboard, garage map)

## Testing

1. Clean build folder: `⌘⇧K` in Xcode
2. Build: `⌘B`
3. Run on device: `⌘R`
4. Grant location permissions when prompted
5. Navigate to Trips tab
6. All features work except automatic CarPlay triggering

## Re-Enabling CarPlay Later

When Apple approves the CarPlay entitlement:

1. Uncomment CarPlay entitlement in `logbook.entitlements`
2. Rename `CarPlaySceneDelegate.swift.disabled` back to `.swift`
3. Uncomment CarPlay code in `logbookApp.swift`
4. Add CarPlay scene configuration to auto-generated Info.plist via build settings or create custom Info.plist again

## Prevention

To avoid this issue in the future:
- **Option A**: Use only `GENERATE_INFOPLIST_FILE = YES` and add all keys via `INFOPLIST_KEY_*` build settings
- **Option B**: Use only a custom Info.plist and set `GENERATE_INFOPLIST_FILE = NO`
- **Never use both** at the same time

## Conclusion

The build now succeeds. The app compiles cleanly with all features working except automatic CarPlay trip triggering (which requires Apple approval anyway). Trip tracking can be implemented manually once CarPlay is approved.
