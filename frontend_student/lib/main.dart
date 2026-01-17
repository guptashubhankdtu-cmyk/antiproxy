import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_gate.dart';
import 'services/student_data_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudentApp());
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => StudentDataService(),
      child: MaterialApp(
        title: 'AttendEase Pro',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
      ),
    );
  }
}
