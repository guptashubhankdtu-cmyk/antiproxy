# AIMS Student App

A Flutter-based mobile application for students to view their attendance records and class information.

## Features

- **Google Sign-In Authentication**: Students login using their registered email
- **Class List**: View all enrolled classes with teacher information and schedule
- **Attendance Statistics**: Detailed attendance stats with:
  - Overall attendance percentage
  - Present/Absent/Late/Excused counts
  - Visual pie chart representation
  - Complete attendance history
- **Read-Only Access**: Students can only view their own attendance data

## Prerequisites

- Flutter SDK (>=3.3.0)
- Android Studio / Xcode for mobile development
- Backend API running (anti-proxy-postresql)

## Setup

### 1. Install Dependencies

```bash
cd frontend_student
flutter pub get
```

### 2. Configure API Endpoint

Update the `baseUrl` in `lib/services/student_data_service.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://YOUR_BACKEND_IP:8000',
);
```

Or run with environment variable:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_BACKEND_IP:8000
```

### 3. Google Sign-In Setup

The app uses Google Sign-In for authentication. Make sure:
- Your email is registered in the `students` table in the database
- The `serverClientId` in `student_data_service.dart` matches your backend OAuth configuration

### 4. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── auth_gate.dart           # Authentication gate widget
├── models/
│   ├── class_model.dart     # Class data model
│   └── attendance_stats.dart # Attendance statistics model
├── services/
│   └── student_data_service.dart # API service for student operations
└── ui/
    ├── splash_screen.dart    # Initial splash screen
    ├── home_page.dart        # Main home page with class list
    └── attendance_detail_page.dart # Attendance details with charts
```

## API Endpoints Used

- `POST /auth/google/student` - Student authentication
- `GET /students/me/classes` - Get enrolled classes
- `GET /students/me/classes/{classId}/attendance` - Get attendance stats for a class

## Building for Release

### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Troubleshooting

### Sign-in fails with "Not registered as a student"

- Verify your email exists in the `students` table
- Check that `email` or `dtu_email` column matches your Google account email

### Cannot load classes

- Ensure backend is running and accessible
- Check API endpoint configuration
- Verify JWT token is being stored correctly

### Charts not displaying

- Make sure `fl_chart` package is properly installed
- Check that attendance data is being fetched correctly

## Security

- JWT tokens are stored securely using `flutter_secure_storage`
- All API calls require authentication
- Students can only access their own data

## License

This project is part of the AIMS (Attendance and Information Management System) suite.
