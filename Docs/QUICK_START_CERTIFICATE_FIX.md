# 🚀 Quick Start - Fix Certificate Error (5 Minutes)

## The Problem
```
❌ "Unable to verify app"
❌ App won't install on your iPhone
```

## The Solution (3 Steps)

---

### ✅ **STEP 1: Register App Group** (2 min)

Go here: **https://developer.apple.com/account/resources/identifiers/list/applicationGroup**

Click **`+`** button (top right)

```
┌─────────────────────────────────────┐
│ Select: App Groups                  │
│                                     │
│ [●] App Groups                      │
│ [ ] App IDs                         │
│                                     │
│              [Continue]             │
└─────────────────────────────────────┘
```

Fill in:
```
Description:  Logbook App Group
Identifier:   group.com.personal.logbook
```

Click **[Register]**

---

### ✅ **STEP 2: Link App Group to App** (2 min)

Go here: **https://developer.apple.com/account/resources/identifiers/list**

Find or create: **`com.personal.logbook`**

Click on it → Edit

Scroll to **App Groups** → ☑️ Check the box

Click **[Configure]**

Select: ☑️ `group.com.personal.logbook`

Click **[Save]** → **[Continue]** → **[Save]**

**Repeat for widget:**
- Bundle ID: `com.personal.logbook.logbookwidget`
- Enable App Groups
- Select `group.com.personal.logbook`

---

### ✅ **STEP 3: Rebuild in Xcode** (1 min)

Open Xcode:

```bash
open logbook.xcodeproj
```

1. **Product** → **Clean Build Folder** (⌘⇧K)
2. **Product** → **Build** (⌘B)
3. Select your iPhone as destination
4. **Product** → **Run** (⌘R)

If you see a signing warning:
- Click **Try Again**
- Wait for profile to download

---

### ✅ **STEP 4: Trust on Device** (30 sec)

On your iPhone:

```
Settings
  → General
    → VPN & Device Management
      → Apple Development: willehond0721@gmail.com
        → [Trust]
```

---

## ✅ Done!

App should now install and run on your device! 🎉

---

## 🆘 Still Not Working?

### Error: "No profiles for com.personal.logbook"
**Fix:** You need a **paid Apple Developer account** ($99/year)
- Free accounts can't use App Groups
- Upgrade at: https://developer.apple.com/programs/

### Error: "Failed to create provisioning profile"
**Fix:** Run the cleanup script again:
```bash
./fix-certificates.sh
```
Then repeat Step 3

### Error: "App Group not found"
**Fix:** Make sure you completed Step 1 exactly:
- Identifier must be: `group.com.personal.logbook`
- No typos, no extra spaces

---

## 📚 More Help

- **Full guide:** `CERTIFICATE_TROUBLESHOOTING.md`
- **Summary:** `CERTIFICATE_FIX_SUMMARY.md`
- **Diagnostic:** Run `./diagnose-certificates.sh`

---

**Total time: 5 minutes** ⏱️

**Result: App works on device** ✅
