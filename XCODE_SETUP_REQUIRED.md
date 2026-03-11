# ⚠️ IMPORTANT: Xcode Configuration Required

## Build Error: Multiple Info.plist Files

The build is currently failing with:
```
error: Multiple commands produce 'logbook.app/Info.plist'
```

This happens because:
1. We created a custom `Info.plist` with CarPlay and location permissions
2. The project is still set to **auto-generate** Info.plist

## ✅ How to Fix (2 minutes in Xcode)

### Step 1: Disable Auto-Generation
1. Open `logbook.xcodeproj` in Xcode
2. Select the **logbook** target (main app, not widget)
3. Go to **Build Settings** tab
4. Search for: `Generate Info.plist File`
5. Change from **Yes** → **No**

### Step 2: Point to Custom Info.plist
1. Still in **Build Settings**
2. Search for: `Info.plist File`
3. Set value to: `logbook/Info.plist`

### Step 3: Clean and Build
1. Press **⌘⇧K** (Clean Build Folder)
2. Press **⌘B** (Build)
3. ✅ Build should succeed

---

## Why This Is Necessary

The custom `Info.plist` includes:
- **Location permissions** (Always, When In Use)
  - Required for background trip tracking
- **Background modes** (location, external-accessory)
  - Enables GPS recording while connected to CarPlay
- **CarPlay scene configuration**
  - Registers `CarPlaySceneDelegate` for automatic trip start/stop

Auto-generated plists don't support these complex configurations.

---

## After Fixing

You can then:
1. Run the app in simulator: **⌘R**
2. Connect CarPlay: **Simulator Menu → I/O → CarPlay → Connect CarPlay**
3. Simulate location: **Debug → Simulate Location → City Run**
4. Watch trips get recorded automatically
5. Disconnect CarPlay to stop tracking
6. Open **Trips** tab to see your recorded trip

---

**Current Status:** Code is complete ✅ | Xcode configuration needed ⚠️
