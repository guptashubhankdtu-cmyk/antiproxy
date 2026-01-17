import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/dtu_logo.png', width: 140, height: 140),
            const SizedBox(height: 16),
            const Text('Anti Proxy',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('DTU - Attendance Software'),
          ],
        ),
      ),
    );
  }
}
