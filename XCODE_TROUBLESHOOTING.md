# Xcode Scheme & Live Activities Troubleshooting Guide

## Issue 1: Widget Extension Launches Instead of Main App

### Problem
When you press Run (⌘R) in Xcode, it launches the widget extension instead of the main Logbook app.

### Solution: Select the Correct Scheme

**In Xcode:**

1. **Look at the top toolbar** (left of the Play/Stop buttons)
2. You'll see a dropdown that says either:
   - `logbook` ← **This is correct! Select this one**
   - `logbookwidgetExtension` ← Wrong, this runs the widget

3. **Click the dropdown** and select **`logbook`**

**Visual Reference:**
```
┌──────────────────────────────────────────┐
│  [logbook ▾]  iPhone 15 Pro ▾  ▶︎  ◼︎    │
│   ↑                                      │
│   Click here and select "logbook"       │
└──────────────────────────────────────────┘
```

### Alternative: Edit Scheme

If the dropdown doesn't appear or keeps defaulting to widget:

1. Click **Product** menu → **Scheme** → **Edit Scheme...**
2. In the left sidebar, select **Run**
3. Under **Info** tab, check that **Executable** is set to **`logbook.app`**
4. If it's set to `Ask on Launch` or `logbookwidgetExtension.appex`, change it to **`logbook.app`**
5. Click **Close**

---

## Issue 2: Live Activities Not Appearing

### Checklist of Things to Verify

Run through this checklist systematically:

#### ✅ 1. iOS Version Check
**Requirement:** iOS 16.1 or later

**How to Check:**
- Simulator: Click device name → Should say iOS 18.0 or similar
- Real Device: Settings → General → About → Software Version

**If iOS 16.0 or earlier:**
- Live Activities won't work at all
- Update simulator or device

---

#### ✅ 2. Device Compatibility
**Dynamic Island:** iPhone 14 Pro, 15 Pro, 16 Pro or later only  
**Lock Screen Activities:** iPhone XS or later

**On Older Devices:**
- Dynamic Island won't show (not supported)
- But Lock Screen should still work
- Check Lock Screen when device is locked

---

#### ✅ 3. Build Settings Check

**Verify NSSupportsLiveActivities is enabled:**

In Xcode:
1. Select **logbook** target
2. Go to **Build Settings**
3. Search for `NSSupportsLiveActivities`
4. Should be set to **YES**

**If not found or set to NO:**
- I already added it to `project.pbxproj`
- Clean build (⌘⇧K) and rebuild (⌘B)

---

#### ✅ 4. User Permission

**First Time Only:**
When you start your first trip, iOS shows:
```
╔═══════════════════════════════════╗
║  "Logbook" Would Like to Display  ║
║     Live Activities                ║
║                                    ║
║    [Don't Allow]    [Allow]        ║
╚═══════════════════════════════════╝
```

**You MUST tap "Allow"!**

**If you tapped "Don't Allow" by accident:**

1. Go to **Settings** app
2. Scroll down to **Logbook**
3. Enable **Live Activities** toggle
4. Force quit and relaunch the app
5. Start a new trip

---

#### ✅ 5. Low Power Mode Check

**Live Activities are DISABLED in Low Power Mode!**

**Check:**
- Settings → Battery → Low Power Mode → **OFF**

**Quick Visual Check:**
- Battery icon in status bar is **white/black** (normal)
- Battery icon is **yellow** = Low Power Mode ON (activities disabled)

---

#### ✅ 6. Console Logging

**Watch the Xcode console when starting a trip:**

**Good Output (Working):**
```
📊 Live Activity Authorization Status:
  - areActivitiesEnabled: true
  - frequentPushesEnabled: false
🚀 Requesting Live Activity...
✅ Live Activity started successfully!
   Activity ID: <some-uuid>
   State: active
```

**Bad Output (Not Working):**
```
⚠️ Live Activities require iOS 16.1 or later
```
→ **Update iOS**

```
⚠️ Live Activities not enabled by user
   Go to Settings → Logbook → Live Activities → Enable
```
→ **Enable in Settings**

```
❌ Failed to start Live Activity: <error>
   Error details: ...
```
→ **Read the error message, it tells you what's wrong**

---

#### ✅ 7. Widget Extension Target

**The widget extension must have access to the activity attributes:**

**Verify these files exist:**
- `/logbook/Models/TripLiveActivityAttributes.swift` (main app)
- `/logbookwidget/TripLiveActivityAttributes.swift` (widget - **COPY**)

**If the widget copy is missing:**
```bash
cp logbook/Models/TripLiveActivityAttributes.swift logbookwidget/
```

Then rebuild.

---

#### ✅ 8. Clean Build

Sometimes Xcode caches cause issues:

1. **⌘⇧K** - Clean Build Folder
2. **⌘⌥⇧K** - Clean Build Folder (hold ⌥)
3. Quit Xcode completely
4. Delete Derived Data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/logbook-*
   ```
5. Reopen Xcode
6. **⌘B** - Build
7. **⌘R** - Run

---

### Testing Live Activities Step-by-Step

**Follow this exact sequence:**

#### Step 1: Start Fresh
1. Force quit the app if running
2. Clear console (⌘K in Xcode)
3. Make sure correct scheme is selected (`logbook`, not widget)

#### Step 2: Launch App
1. Press **⌘R** to run
2. Wait for app to launch on simulator/device
3. Watch console for startup messages

#### Step 3: Grant Permissions
1. **Location permission prompt** appears → Tap **"Allow While Using App"** or **"Allow Always"**
2. **Live Activities permission prompt** appears → Tap **"Allow"** (critical!)

#### Step 4: Start Trip
1. Tap **Trips** tab at bottom
2. Tap blue **"Start New Trip"** button
3. Select a vehicle (or "No specific car")
4. **Immediately watch:**
   - Console for: `✅ Live Activity started successfully!`
   - Dynamic Island (top of screen) for activity pill
   - If using simulator, click Dynamic Island to interact

#### Step 5: Verify Activity
**In Simulator:**
- Click the Dynamic Island pill at top
- Should expand showing distance and speed
- Right-click → **Show Compact/Expanded** to test views

**On Device:**
- Long-press the Dynamic Island
- Should expand showing trip details
- Lock device → Check Lock Screen

#### Step 6: Check Updates
1. Simulate movement:
   - Simulator: Debug → Location → **City Run**
   - Device: Xcode → Debug → Simulate Location → **City Bicycle Ride**
2. Every 15 seconds, console should show:
   ```
   📍 Point recorded - Speed: 85.0km/h, Distance: 12.34km
   📍 Live Activity updated - Distance: 12.34km, Speed: 85km/h
   ```
3. Dynamic Island should update with new values

#### Step 7: Stop Trip
**Test both methods:**

**Method A - From App:**
1. Open app
2. Go to Trips tab
3. Tap red "Stop Trip" button
4. Console: `✅ Live Activity ended successfully`

**Method B - From Dynamic Island:**
1. Expand Dynamic Island (long-press)
2. Tap "Stop Trip" button
3. App opens automatically
4. Trip stops

---

## Common Errors and Solutions

### Error: "Live Activities require iOS 16.1 or later"
**Solution:** Update simulator/device to iOS 16.1+

### Error: "Live Activities not enabled by user"
**Solution:** Settings → Logbook → Enable Live Activities

### Error: "Failed to start Live Activity: <some error>"
**Solutions:**
1. Check console for specific error details
2. Verify `NSSupportsLiveActivities = YES` in build settings
3. Clean build and retry
4. Check that both TripLiveActivityAttributes files exist

### Activity Appears But Doesn't Update
**Solutions:**
1. Verify location permission is "Always" or "While Using"
2. Make sure you're actually moving (or simulating)
3. Check console for `📍 Point recorded` messages every 15s
4. If no points recorded → location tracking issue, not Live Activity issue

### Dynamic Island Empty/Black
**Solutions:**
1. Simulator: Click it to expand, might be in collapsed state
2. Device: Long-press to expand
3. Check if multiple activities are running (shows minimal view)
4. Restart simulator/device

### Stop Button Doesn't Work
**Solutions:**
1. Verify deep link handler in `logbookApp.swift` (already added)
2. Check console for: `🔗 Deep link: Stop trip`
3. If nothing in console → app not receiving URL
4. Test manually: `xcrun simctl openurl booted "logbook://stopTrip"`

---

## Quick Diagnostics Script

Run this in Terminal to check your setup:

```bash
cd /Users/jandrebadenhorst/Projects/logbook

echo "=== Checking Live Activities Setup ==="
echo ""

echo "1. Checking for NSSupportsLiveActivities..."
grep -r "NSSupportsLiveActivities" logbook.xcodeproj/project.pbxproj && echo "✅ Found" || echo "❌ Missing"

echo ""
echo "2. Checking for TripLiveActivityAttributes files..."
ls logbook/Models/TripLiveActivityAttributes.swift && echo "✅ Main app copy exists" || echo "❌ Main app copy missing"
ls logbookwidget/TripLiveActivityAttributes.swift && echo "✅ Widget copy exists" || echo "❌ Widget copy missing"

echo ""
echo "3. Checking for TripLiveActivity widget..."
ls logbookwidget/TripLiveActivity.swift && echo "✅ Widget implementation exists" || echo "❌ Widget implementation missing"

echo ""
echo "4. Checking ActivityKit import..."
grep -r "import ActivityKit" logbook/Services/TripTrackingService.swift && echo "✅ ActivityKit imported" || echo "❌ ActivityKit not imported"

echo ""
echo "=== Setup Check Complete ==="
```

---

## Still Not Working?

### Debug Mode - Maximum Verbosity

I've already added extensive logging. When you start a trip, you should see **detailed output** in the console. Copy the **entire console output** and look for:

- **Red ❌ symbols** = Errors
- **Yellow ⚠️ symbols** = Warnings
- **Green ✅ symbols** = Success

The error messages will tell you exactly what's wrong.

### Last Resort

If absolutely nothing works:

1. **Create a new test trip:**
   ```
   Open app → Trips → Start New Trip → Select any car → Watch console
   ```

2. **Copy the FULL console output**

3. **Check specifically for:**
   - `📊 Live Activity Authorization Status:`
   - `areActivitiesEnabled: true` ← Must be true!

4. **If `areActivitiesEnabled: false`:**
   - Settings → Logbook → Live Activities → Enable
   - Force quit app
   - Try again

---

## Summary

**Main App Won't Run:**
- Select `logbook` scheme (not `logbookwidgetExtension`)

**Live Activities Don't Appear:**
1. iOS 16.1+ required
2. User must grant permission (Settings → Logbook → Live Activities)
3. Low Power Mode must be OFF
4. `NSSupportsLiveActivities = YES` in build settings
5. Both TripLiveActivityAttributes files must exist
6. Watch console for detailed error messages

**Everything looks right but still doesn't work:**
- Clean build (⌘⇧K)
- Delete Derived Data
- Restart Xcode
- Try on a different simulator/device

The enhanced logging I added will pinpoint the exact issue! 🔍
