# Manual Trip Tracking - User Guide

## How to Start a Trip Manually

The trip tracking feature is fully functional and ready to use! Here's how to access it:

### Location of Trip Controls

📍 **Main Navigation**: Open the app → Tap the **"Trips"** tab at the bottom

### Starting a Trip

1. **Navigate to Trips Tab**
   - Open the app
   - Tap the "Trips" icon in the bottom tab bar (map icon)

2. **Start New Trip Button**
   - You'll see a large blue button that says **"Start New Trip"**
   - This button appears:
     - ✅ In the empty state (when you have no trips yet)
     - ✅ At the top of the trips list (when you have existing trips)
     - ✅ Below the active trip banner (when a trip is running)

3. **Select a Vehicle (Optional)**
   - When you tap "Start New Trip", a sheet appears
   - Choose one of your vehicles from the list, OR
   - Select "No specific car" to track without linking to a vehicle
   - The trip starts immediately after selection

### While Trip is Running

When a trip is actively tracking:

**Live Stats Banner** (red background at top):
- 🔴 Pulsing red dot indicator
- Distance traveled in real-time
- Current speed in km/h

**Stop Trip Button** (below the banner):
- Large red button that says **"Stop Trip"**
- Tap to end tracking and save the trip

### After Trip is Stopped

Your completed trip appears in the list showing:
- 📅 Date and time
- 🗺️ Total distance
- ⏱️ Duration
- 🚗 Average and max speed
- 🚙 Vehicle used (if selected)

Tap any trip to see:
- Full route on a map
- Start and end locations
- Speed chart over time
- Detailed statistics
- Share button to export trip summary

## Location Permissions Required

For trip tracking to work, you need to grant location permissions:

### First Launch
1. App will prompt: **"Logbook would like to access your location"**
2. Choose: **"While Using the App"** or **"Always"**

### For Background Tracking
- **"Always"** permission is required for tracking to continue when the app is in the background or the screen is locked
- You can change this in Settings → Logbook → Location → Always

### Permission States
- ✅ **Always**: Full background tracking works
- ⚠️ **While Using**: Only tracks when app is open (limited)
- ❌ **Never**: Trip tracking disabled

## UI Overview

```
┌─────────────────────────────────┐
│         🗺️ Trips               │  ← Navigation Title
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🔴 Recording Trip         │ │  ← Active Trip Banner
│  │ 📍 12.5 km  🚗 85 km/h   │ │     (only when tracking)
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │  🛑 Stop Trip             │ │  ← Stop Button (when tracking)
│  └───────────────────────────┘ │
│                                 │
│  OR                             │
│                                 │
│  ┌───────────────────────────┐ │
│  │  ▶️ Start New Trip        │ │  ← Start Button (when idle)
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🗺️  Mar 8, 2026           │ │
│  │ 📍 145.2 km  ⏱️ 2h 15m    │ │  ← Trip List
│  │ Avg: 64 km/h • Max: 120  │ │
│  │ 🚙 2022 Toyota Corolla    │ │
│  └───────────────────────────┘ │
│  ...more trips...             │
│                                 │
└─────────────────────────────────┘
```

## Empty State (No Trips Yet)

```
┌─────────────────────────────────┐
│         🗺️ Trips               │
├─────────────────────────────────┤
│                                 │
│                                 │
│           🗺️                   │
│      (large icon)               │
│                                 │
│     No Trips Yet                │
│                                 │
│  Tap 'Start New Trip' to begin │
│  tracking your journey          │
│                                 │
│                                 │
│  ┌───────────────────────────┐ │
│  │  ▶️ Start New Trip        │ │  ← Button in empty state
│  └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

## Features

### Automatic Recording
- 📍 Records GPS coordinates every 15 seconds
- 🚫 Only saves points if you've moved at least 10 meters (prevents duplicate points when stationary)
- ⏱️ Continues tracking in the background (with "Always" permission)
- 🔋 Optimized for battery efficiency

### What's Tracked
- Start date/time and end date/time
- Total distance traveled (in km)
- Duration (hours and minutes)
- Average speed (calculated from all recorded points)
- Maximum speed reached
- Complete GPS route (lat/lon coordinates)
- Speed at each recorded point
- Vehicle used (optional)

### Data Storage
- All trip data stored locally with SwiftData
- Syncs across your devices via iCloud (if enabled)
- Persists between app launches
- Can be deleted with swipe-to-delete

## Troubleshooting

### "Start New Trip" button doesn't appear
- ✅ Make sure you're on the **Trips tab** (bottom navigation)
- ✅ Wait a moment for the view to load

### Trip doesn't track in background
- ✅ Grant **"Always"** location permission in Settings → Logbook
- ✅ Ensure "Low Power Mode" is disabled (limits background activity)
- ✅ Check that location services are enabled: Settings → Privacy → Location Services

### No distance or speed being recorded
- ✅ Make sure you're actually moving (at least 10 meters)
- ✅ Check location permission is granted
- ✅ Try moving outdoors for better GPS signal

### App crashes when starting trip
- ✅ Ensure location permissions are granted
- ✅ Check console logs for error messages
- ✅ Restart the app
- ✅ See `LOCATION_CRASH_FIX.md` for technical details

## Testing Without Moving

To test trip tracking without physically moving:

### iOS Simulator
1. Run app in simulator
2. Start a trip
3. Simulator menu → **Debug → Location → City Run**
4. Watch the trip record distance and speed

### Real Device
1. Connect device to Mac
2. In Xcode: **Debug → Simulate Location → City Bicycle Ride**
3. Or use any other simulated route

## Future Enhancements (Coming Soon)

- 🚗 **CarPlay Integration**: Automatic trip start when connecting to CarPlay (waiting on Apple approval)
- 📤 **Export Options**: Export trips as GPX files
- 📊 **Statistics**: Weekly/monthly trip summaries
- 🏆 **Achievements**: Track milestones
- ⛽ **Fuel Correlation**: Link trips to fuel log entries

## Summary

✅ Trip tracking is **fully functional** right now  
✅ Button location: **Trips tab** in bottom navigation  
✅ Works in background with proper permissions  
✅ All data persists and syncs  
✅ Ready to use immediately  

**Just tap "Trips" → "Start New Trip" → Select vehicle → Start driving!** 🚗💨
