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
3. Choose **Start in test mode** for development (switch to production rules before release)
4. Select a region close to your users

### 4. Firestore Security Rules (Production)

Replace the default rules with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /players/{playerId} {
      allow read, write: if true;
    }
    match /teams/{teamId} {
      allow read, write: if true;
    }
    match /tournaments/{tournamentId} {
      allow read, write: if true;
    }
  }
}
```

For authenticated access, replace `if true` with `if request.auth != null`.

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
