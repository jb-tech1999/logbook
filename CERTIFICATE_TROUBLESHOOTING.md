# Certificate Verification Troubleshooting Guide

## ❌ Problem
**"Unable to verify app" or "Untrusted Developer" error when installing on device**

---

## 🔍 Root Causes

### 1. **App Group Not Registered** (Most Common)
Your app uses `group.com.personal.logbook` but this identifier may not be registered in your Apple Developer account.

### 2. **Provisioning Profile Missing App Group**
The automatically generated provisioning profile doesn't include the App Group capability.

### 3. **Development Certificate Not Trusted**
Your device doesn't trust the development certificate used to sign the app.

### 4. **Bundle Identifier Conflict**
`com.personal.logbook` might be already registered to a different team or needs to be created.

---

## ✅ Solution Steps (In Order)

### **Step 1: Register App Group in Apple Developer Portal**

1. Go to: https://developer.apple.com/account/resources/identifiers/list/applicationGroup
2. Click the **`+`** button (top right)
3. Select **App Groups** → Continue
4. Enter:
   - **Description**: `Logbook App Group`
   - **Identifier**: `group.com.personal.logbook`
5. Click **Register**

---

### **Step 2: Update App ID to Include App Group**

1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Find or create: **`com.personal.logbook`**
   - If it doesn't exist, click **`+`** → **App IDs** → Continue
   - Description: `Logbook`
   - Bundle ID: `com.personal.logbook`
   - Select **Explicit**
3. Click on the App ID to edit it
4. Scroll to **App Groups** → Check the box
5. Click **Configure**
6. Select `group.com.personal.logbook`
7. Click **Save** → **Continue** → **Save**

---

### **Step 3: Register Widget Extension App ID**

1. In the same Identifiers list, click **`+`**
2. Select **App IDs** → Continue
3. Enter:
   - Description: `Logbook Widget`
   - Bundle ID: `com.personal.logbook.logbookwidget`
   - Explicit Bundle ID
4. Enable **App Groups**
5. Click **Configure** → Select `group.com.personal.logbook`
6. Click **Continue** → **Register**

---

### **Step 4: Clean and Re-sign in Xcode**

1. Open Xcode
2. Select the **logbook** target → **Signing & Capabilities**
3. Verify:
   - ✅ **Automatically manage signing** is checked
   - ✅ **Team**: Shows your team name (BGU4626AR9)
   - ✅ **App Groups** capability is present with `group.com.personal.logbook`
4. If you see a yellow warning ⚠️ → Click **Try Again** or **Download Profile**
5. Repeat for **logbookwidgetExtension** target
6. **Product** → **Clean Build Folder** (⌘⇧K)
7. **Product** → **Build** (⌘B)

---

### **Step 5: Trust Certificate on Device**

**If you still see "Untrusted Developer":**

1. On your iPhone/iPad:
2. Go to **Settings** → **General** → **VPN & Device Management**
3. Find your developer certificate (Apple Development: [Your Name])
4. Tap it → Tap **Trust "[Your Name]"**
5. Tap **Trust** in the popup

---

### **Step 6: Delete and Reinstall App**

1. Delete the existing Logbook app from your device
2. In Xcode, run the app again (⌘R)
3. When prompted for location/Live Activities permissions, tap **Allow**

---

## 🚨 Still Not Working?

### **Check Development Certificate Validity**

Run this command in Terminal:
```bash
security find-identity -v -p codesigning
```

You should see:
```
1) [Certificate Hash] "Apple Development: Your Name (TEAM_ID)"
```

If you see `(CSSMERR_TP_CERT_EXPIRED)` or `(CSSMERR_TP_CERT_REVOKED)`, your certificate expired.

**Fix:**
1. Go to: https://developer.apple.com/account/resources/certificates/list
2. Find your development certificate
3. If expired, revoke it and create a new one:
   - Click **`+`** → **iOS Development** → Continue
   - Follow the CSR steps
   - Download and double-click to install
4. Back to Xcode → Clean Build Folder → Build again

---

### **Check Provisioning Profile**

Run this command:
```bash
open ~/Library/MobileDevice/Provisioning\ Profiles/
```

Delete all `.mobileprovision` files in this folder, then:
1. Xcode → Preferences → Accounts
2. Select your Apple ID
3. Click **Download Manual Profiles**
4. Clean Build Folder → Build again

---

### **Reset All Signing Settings**

If nothing works, reset everything:

1. Xcode → Select **logbook** target
2. **Signing & Capabilities**
3. **Uncheck** "Automatically manage signing"
4. Delete any existing provisioning profiles shown
5. **Check** "Automatically manage signing" again
6. Wait for Xcode to regenerate profiles
7. Repeat for **logbookwidgetExtension** target
8. Clean Build Folder → Build

---

## 📋 Verification Checklist

Before building, verify these in Xcode:

### **Main App Target (logbook)**
- ✅ Bundle Identifier: `com.personal.logbook`
- ✅ Team: BGU4626AR9
- ✅ Signing Certificate: Apple Development
- ✅ Provisioning Profile: Shows a profile name (not "None")
- ✅ App Groups capability present
- ✅ `group.com.personal.logbook` checked

### **Widget Extension Target (logbookwidgetExtension)**
- ✅ Bundle Identifier: `com.personal.logbook.logbookwidget`
- ✅ Team: BGU4626AR9
- ✅ Signing Certificate: Apple Development
- ✅ Provisioning Profile: Shows a profile name
- ✅ App Groups capability present
- ✅ `group.com.personal.logbook` checked

---

## 🔧 Quick Fix Script

Run this in Terminal from your project directory:

```bash
#!/bin/bash

echo "🧹 Cleaning Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

echo "🧹 Cleaning provisioning profiles..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*

echo "🔑 Re-downloading profiles..."
# This will prompt Xcode to regenerate profiles on next build

echo "✅ Done! Now:"
echo "1. Open Xcode"
echo "2. Product → Clean Build Folder (⌘⇧K)"
echo "3. Product → Build (⌘B)"
echo "4. Run on device (⌘R)"
```

---

## 🆘 Last Resort

If absolutely nothing works:

1. Create a **new, unique bundle identifier**:
   - Change `com.personal.logbook` → `com.personal.logbook.app`
   - Change widget to `com.personal.logbook.app.widget`
2. Update in Xcode build settings
3. Create new App IDs in Developer Portal with these identifiers
4. Clean Build Folder → Build → Run

---

## 📞 Common Error Messages

| Error | Cause | Fix |
|---|---|---|
| "Unable to verify app" | Certificate not trusted | Settings → General → VPN & Device Management → Trust |
| "Failed to create provisioning profile" | App Group not in portal | Register App Group in Developer Portal |
| "No profiles for 'com.personal.logbook'" | Bundle ID not registered | Create App ID in Developer Portal |
| "The executable was signed with invalid entitlements" | App Group mismatch | Verify App Group ID matches in code and portal |
| "Your development team does not support this capability" | Free Apple ID (not paid) | Need paid Apple Developer Program ($99/year) |

---

## ✅ Expected Result

After following all steps, you should see in Xcode Signing & Capabilities:

```
✅ Provisioning profile "iOS Team Provisioning Profile: com.personal.logbook"
✅ Signing Certificate: Apple Development: [Your Name]
✅ No warnings or errors
```

And the app should install and run on your device without any certificate errors!
