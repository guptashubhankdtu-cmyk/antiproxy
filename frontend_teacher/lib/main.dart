// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_gate.dart';
import 'services/http_data_service.dart';
import 'services/local_data_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AntiProxyApp());
}

class AntiProxyApp extends StatelessWidget {
  const AntiProxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => HttpDataService()),
        ChangeNotifierProvider(create: (context) => LocalDataService()),
      ],
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
