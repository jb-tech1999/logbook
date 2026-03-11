# Live Activities Quick Start Guide

## 🚀 How to See Your Trip in the Dynamic Island

### Step 1: Start a Trip
1. Open **Logbook** app
2. Tap **Trips** tab (bottom navigation)
3. Tap the blue **"Start New Trip"** button
4. Select your vehicle (or "No specific car")

### Step 2: Watch the Dynamic Island
✨ **The Live Activity appears instantly!**

```
iPhone with Dynamic Island:
┌────────────────────────────┐
│  [📍 0.0]    [0 🚗]        │  ← Compact view
└────────────────────────────┘
```

### Step 3: Drive Around (or Simulate)
- In **Simulator**: Debug → Location → City Run
- On **Device**: Actually drive, or use Xcode location simulation

**Updates every 15 seconds!**

### Step 4: Expand the Dynamic Island
**Long-press** or **tap and hold** on the Dynamic Island

```
┌──────────────────────────────────┐
│                                  │
│  📍 12.5 km         85 km/h 🚗  │  ← Distance & Speed
│                                  │
│      🚙 Toyota Corolla           │  ← Your vehicle
│      Timer: 00:15:32             │  ← Time elapsed
│                                  │
│   [🛑 Stop Trip]                 │  ← TAP THIS
│                                  │
└──────────────────────────────────┘
```

### Step 5: Stop the Trip
**Two ways:**

#### From Dynamic Island:
1. Expand the island (long-press)
2. Tap **"Stop Trip"** button
3. App opens and stops tracking
4. Activity shows final stats for 60 seconds

#### From App:
1. Open app
2. Go to Trips tab
3. Tap red **"Stop Trip"** button

## 🔒 Lock Screen View

Lock your iPhone while a trip is active:

```
┌─────────────────────────────────────┐
│                                     │
│  📍 Trip in Progress    ⏱️ 00:15:32 │
│                                     │
│  Distance              Speed        │
│  📏 12.5 km       🚗 85 km/h       │
│                                     │
│  ──────────────────────────────     │
│                                     │
│  🚙 2022 Toyota Corolla             │
│                                     │
└─────────────────────────────────────┘
           Swipe up to unlock
```

**Tap the activity** to open the app!

## 📱 What You'll See

### While Driving
- **Distance**: Updates in real-time as you drive
- **Speed**: Shows your current speed in km/h
- **Timer**: Counts up from trip start time
- **Vehicle**: Shows which car you're driving (if selected)

### Status Indicators
- 🟢 **Pulsing animation** = Activity is active and updating
- ⏱️ **Timer running** = Trip is being recorded
- 📍 **Distance increasing** = GPS tracking working

## ⚙️ First-Time Setup

### When you start your first trip:

**iOS will ask:**
```
╔═══════════════════════════════════╗
║  Logbook Would Like to Display    ║
║     Live Activities                ║
║                                    ║
║  This lets you see trip updates   ║
║  on your Lock Screen and in the   ║
║  Dynamic Island.                   ║
║                                    ║
║    [Don't Allow]    [Allow]        ║
╚═══════════════════════════════════╝
```

**Tap "Allow"** to enable Live Activities!

### If you accidentally denied it:

1. Go to **Settings**
2. Scroll to **Logbook**
3. Enable **Live Activities**

## 🎯 Quick Troubleshooting

### "I don't see anything!"

✅ **Check these:**
1. Do you have iPhone 14 Pro or later? (for Dynamic Island)
   - *Older phones: Check Lock Screen instead*
2. Is the trip actually tracking?
   - *Look for the red banner in the app*
3. Is Low Power Mode enabled?
   - *Settings → Battery → turn off Low Power Mode*
4. Did you allow Live Activities?
   - *Settings → Logbook → Live Activities → On*

### "It's not updating!"

✅ **Make sure:**
1. You're actually moving (at least 10 meters)
2. Location permission is set to "Always"
3. The trip is active (see red banner in app)
4. Not in Low Power Mode

### "The stop button doesn't work!"

✅ **Try:**
1. Make sure app is installed and running
2. Close and reopen the app
3. Stop manually from app instead

## 🎉 That's It!

You now have a live, updating trip tracker in your **Dynamic Island** and **Lock Screen**!

**Key Points:**
- ✅ Appears automatically when trip starts
- ✅ Updates every 15 seconds with latest data
- ✅ Stop button works from Dynamic Island
- ✅ Stays visible for 60 seconds after trip ends
- ✅ Works even when app is closed (background tracking)

**Enjoy tracking your trips! 🚗💨**
