# Spark Dating App 🔥

<div align="center">
  <br>
  <h3>Find Your Perfect Match with Spark</h3>
  <p>A modern dating app built with Flutter & Firebase</p>

[![Flutter](https://img.shields.io/badge/Flutter-3.16+-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-13.0+-orange.svg)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-Non--Commercial-blue)](LICENSE)
</div>

## 📱 About The Project

Spark is a modern dating application that helps people find meaningful connections. Built with Flutter and Firebase, it offers a seamless and secure dating experience with real-time features.

### ✨ Key Features

- 🔐 **Authentication**
    - Email/Password Sign Up & Login
    - Google Sign-In Integration
    - Email Verification System
    - Verified User Badges

- 👤 **User Profiles**
    - Customizable profiles
    - Personal bio, interests, and preferences
    - Location-based information
    - Privacy controls

- 💕 **Discovery & Matching**
    - Grid-based discovery interface
    - Advanced filtering (gender, age range)
    - Real-time online status
    - Mutual like matching system

- 💬 **Chat System**
    - Real-time messaging
    - Message history & timestamps
    - Online/offline indicators
    - Block user functionality

- 🛡️ **Safety & Privacy**
    - Block/unblock users
    - Privacy settings (profile visibility, online status)
    - Account management (change password, delete account)

- 🎨 **User Experience**
    - Light/Dark theme support
    - Responsive design
    - Real-time updates

## 🛠️ Built With

- [Flutter](https://flutter.dev) - UI Framework
- [Firebase](https://firebase.google.com) - Backend & Authentication
    - Firebase Auth
    - Cloud Firestore
    - Firebase Storage
- [Provider](https://pub.dev/packages/provider) - State Management
- [Google Sign-In](https://pub.dev/packages/google_sign_in) - Social Auth

## 📋 Prerequisites

Before you begin, ensure you have the following installed:
- Flutter SDK (3.16 or higher)
- Android Studio / VS Code
- Git
- A Firebase account

## 🚀 Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/sasikad1/flutter-firebase-spark-project.git
cd flutter-firebase-spark-project
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Setup

#### Android Setup
1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Add an Android app with package name: `com.spark`
3. Download `google-services.json` and place it in `android/app/`
4. Add SHA-1 fingerprint for Google Sign-In:
   ```bash
   cd android && ./gradlew signingReport
   ```
5. Enable Email/Password and Google Sign-In in Firebase Console

#### Web Setup
1. Add a Web app in Firebase Console
2. Copy the Web Client ID
3. Update `web/index.html`:
   ```html
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID">
   ```

### 4. Run the App
```bash
# For Android
flutter run

# For Web
flutter run -d chrome
```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── providers/                # State management
│   └── theme_provider.dart    # Theme provider
├── screens/                  # UI screens
│   ├── auth_screen.dart       # Login/Signup
│   ├── home_screen.dart       # Main home with tabs
│   ├── discovery_screen.dart  # Profile discovery
│   ├── profile_details_screen.dart # View profiles
│   ├── profile_screen.dart     # Edit profile
│   ├── matches_screen.dart     # Match list
│   ├── chat_screen.dart        # Chat interface
│   ├── settings_screen.dart    # App settings
│   └── blocked_users_screen.dart # Blocked users
└── services/                 # Business logic
    ├── presence_service.dart  # Online status
    └── block_service.dart      # Block functionality
```

## 🎯 Features in Detail

### Authentication Flow
- Users can sign up with email/password or Google
- Email verification required for security
- Automatic profile creation after signup

### Discovery Algorithm
- Shows profiles based on user preferences
- Filters out liked/passed/blocked users
- Real-time updates with Firestore streams

### Matching System
- Mutual likes create instant matches
- Match notifications with animations
- Chat access only for matched users

### Chat System
- Real-time messaging with Firestore
- Online/offline indicators
- Block user from chat interface

## 🤝 Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under a **Non-Commercial License** - see the [LICENSE](LICENSE) file for details.

**Important**: This software may not be used for commercial purposes without explicit permission. For commercial licensing inquiries, please contact: hnkaluarachchi17@gmail.com

## 📞 Contact

Kalu Arachchi - hnkaluarachchi17@gmail.com


## 🙏 Acknowledgments

- Flutter team for amazing framework
- Firebase for robust backend
- All contributors and testers

---

<div align="center">
  Made with ❤️ by Kalu Arachchi
  <br>
  ⭐ Star this repo if you like it!
</div>