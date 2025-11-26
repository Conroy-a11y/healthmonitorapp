Health Monitor App

A Flutter-based health monitoring application with:

Firebase Authentication (Email/Password)

Role-based access (Patient or Doctor)

Local storage using SQLite (sqflite) for offline measurement storage

SharedPreferences for lightweight local settings

Modern, clean UI

Role-based dashboards

Patients: View & add their own measurements

Doctors: View all measurements & add for any patient

📌 Features
🔐 Authentication

Firebase Email/Password authentication

Role selection during sign-up (patient/doctor)

Role saved both in:

Firebase (user.displayName)

SharedPreferences (role)

💾 Local Storage

SharedPreferences

Stores user role

Stores last used email

SQLite (sqflite) local DB

Stores all measurements locally

Measurements include:

Patient ID (UID)

Type (glucose, pressure, etc.)

Value & unit

Recorded time

Created time

📊 Role-Based Dashboards
Patient Dashboard

View your own measurements

Add new measurements

Delete measurements

Quick profile card

Floating action button for adding new entries

Doctor Dashboard

View all measurements (from local DB)

Add measurements for any patient ID

Delete measurements

📝 Add Measurement Screen

Supports multiple measurement types:

Blood glucose

Blood pressure

SpO2

Weight

Date & time picker for measurement timestamp

Doctor mode allows patient ID input

📦 Project Structure Overview
lib/
├── main.dart
├── firebase_options.dart
├── models/
│ └── measurement.dart
├── services/
│ ├── db_helper.dart
│ └── prefs.dart
├── screens/
│ ├── auth_screen.dart
│ ├── patient_dashboard.dart
│ ├── doctor_dashboard.dart
│ └── add_measurement_screen.dart

(Your current code is combined in one file, but can optionally be split like this.)

📚 Dependencies

Add these to your pubspec.yaml:

dependencies:
flutter:
sdk: flutter

firebase_core: ^3.0.0
firebase_auth: ^5.0.0
shared_preferences: ^2.0.15
sqflite: ^2.2.8+4
path: ^1.8.3
path_provider: ^2.0.15
intl: any
cupertino_icons: ^1.0.5

🚀 Getting Started

1. Install Flutter dependencies
   flutter pub get

2. Configure Firebase

Add your firebase_options.dart file (generated via FlutterFire CLI)

Ensure Firebase is initialized before running the app:

await Firebase.initializeApp(
options: DefaultFirebaseOptions.currentPlatform,
);

3. Run the application
   flutter run

🛠 How It Works
Authentication Flow

App listens to FirebaseAuth.instance.authStateChanges()

If user not logged in → show AuthScreen

If logged in → load role and route to correct dashboard

Role Determination Logic

Check SharedPreferences (role)

If missing, check Firebase user.displayName

Fallback to "patient"

Local Database (SQLite)

Table: measurements

Column Type Description
id INTEGER Auto-increment ID
patientId TEXT Firebase UID
type TEXT Measurement type
value REAL Value
unit TEXT Unit (e.g. mg/dL)
recordedAt TEXT Measurement timestamp
createdAt TEXT Created timestamp
📱 Screenshots (Recommended to Add)

Login screen

Patient dashboard

Doctor dashboard

Add measurement screen

🧪 Future Improvements

Sync SQLite ↔ Cloud Firestore

Add charts (fl_chart)

Push notifications

Multi-language support (intl)

📄 License

This project is free to use, modify, and extend.

site live at: https://f7g09rt80y3zmv3tt.share.dreamflow.app
