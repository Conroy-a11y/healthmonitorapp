Vitality App

A modern health-monitoring mobile application built with Flutter, featuring theme support, authentication flow handling, and a clean navigation architecture.

🚀 Overview

Vitality is a Flutter application designed with a focus on user experience and responsive UI.
The app automatically checks whether the user is logged in and routes them to the correct screen:

If logged in → Navigate to Main Navigation

If not logged in → Show Login Page

The app supports both light and dark themes, following the system preference.

📂 Project Structure
lib/
│
├── main.dart # Main entry point of the app
├── theme.dart # Light & dark theme configuration
│
├── screens/
│ ├── login_page.dart # Login screen UI
│ └── main_navigation.dart # Main app UI after login
│
└── services/
└── auth_service.dart # Authentication logic

🧩 Core Features
🔐 Authentication Check

The app uses an AuthChecker widget that performs an async login state check:

Displays a loading spinner while checking.

Routes users dynamically based on their authentication state.

🎨 Theming

lightTheme

darkTheme

Automatic theme switching based on device settings.

🧭 Navigation

Once authenticated, users are redirected to the MainNavigation screen.

🛠️ How It Works
main.dart

Defines the root widget and sets up the themes and app entry point.

void main() {
runApp(const MyApp());
}

AuthChecker

Handles routing based on login status using a FutureBuilder.

FutureBuilder<bool>(
future: AuthService().isLoggedIn(),
...
)

📦 Dependencies

Make sure your pubspec.yaml includes the necessary packages such as:

flutter

Any dependencies required by your auth_service.dart

Additional packages your UI might use

▶️ Getting Started

1. Get dependencies
   flutter pub get

2. Run the app
   flutter run

3. live site: https://f7g09rt8r980y3zmv3tt.share.dreamflow.app

📌 Future Improvements

Add Firebase or backend authentication

Integrate persistent login state storage

Add full user dashboard and medical tracking features

Improve UI/UX transitions

📝 License

This project is open-source and available under your preferred license.
