# Stickball Tournament Tracker - Setup Guide

## Firebase Configuration

This app uses Firebase Firestore for real-time cloud sync so multiple users can update stats simultaneously.

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add project** and follow the wizard
3. Enable **Google Analytics** (optional)

### 2. Add iOS App to Firebase

1. In your Firebase project, click **Add app** → **iOS**
2. Enter bundle ID: `com.stickball.tracker` (or your custom bundle ID)
3. Download `GoogleService-Info.plist`
4. Drag it into the `StickballTracker/` folder in Xcode

### 3. Enable Firestore

1. In Firebase Console → **Build** → **Firestore Database**
2. Click **Create database**
3. Select a region close to your users (you cannot change this later)

### 4. Firestore Security Rules ⚠️ CRITICAL

**Test mode rules expire after 30 days and silently start denying ALL writes.**
When that happens, the iOS Firestore SDK still updates its **local cache**, so
the device that wrote the data shows it correctly — but the data **never
actually reaches the server**, and other devices can't see it. After
reinstalling the app, the data is gone because it only existed in the now-wiped
local cache.

**This is the #1 cause of "tournament works on my phone but not anyone else's"
and "tournament disappeared after I reinstalled".**

This repo includes a `firestore.rules` file with permissive rules that match
the app's design (the app enforces access control client-side via PIN). Deploy
them with the Firebase CLI:

```bash
# 1. Install the CLI (one-time)
npm install -g firebase-tools

# 2. Log in
firebase login

# 3. From the repo root, deploy the rules to your project:
firebase deploy --only firestore:rules --project galactics-ae662
```

Or paste the contents of `firestore.rules` directly into the Firebase Console
under **Firestore Database → Rules → Publish**.

After deploying, test by:
1. Creating a tournament on Phone A
2. Checking Firebase Console → Firestore Database → `tournaments` collection.
   The document should appear there within seconds.
3. Opening the app on Phone B — the tournament should appear automatically.
4. If you see a red **CLOUD SYNC ERROR** banner inside the app, the rules are
   still wrong — re-deploy and check the Firebase Console rules tab.

For authenticated access in the future, replace `if true` with
`if request.auth != null` in `firestore.rules` and redeploy.

### 5. Open in Xcode

1. Open `StickballTracker.xcodeproj` in Xcode 15+
2. Select the **StickballTracker** scheme and an iOS Simulator destination
3. Xcode will resolve the Firebase SPM dependency automatically (FirebaseCore + FirebaseFirestore)
4. Drag `GoogleService-Info.plist` into the StickballTracker group and ensure it's added to the app target
5. Build and run (Cmd+R) on a simulator or device running iOS 17+

## Architecture

- **Models**: `Player`, `Team`, `Tournament`, `Game` - all Codable for Firestore
- **CloudSyncService**: Real-time Firestore listeners keep all connected devices in sync
- **Views**: SwiftUI with Aztec/sci-fi themed design system
- **Theme**: `AztecTheme` provides colors, gradients, and reusable styled components
