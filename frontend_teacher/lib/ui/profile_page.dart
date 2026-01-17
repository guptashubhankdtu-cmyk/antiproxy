// lib/ui/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/http_data_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<HttpDataService>();
    final user = dataService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user data available')),
      );
    }

    final String name = user['name'] ?? user['email'] ?? 'Teacher';
    final String email = user['email'] ?? '';
    final String role = user['role'] ?? 'teacher';
    final String userId = user['id'] ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF6B46C1),
        foregroundColor: Colors.white,
        title: const Text('Teacher Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6B46C1),
                    Color(0xFF6B46C1).withOpacity(0.1),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6B46C1),
                            Color(0xFF0891B2),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF6B46C1).withOpacity(0.3),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Color(0xFF6B46C1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Info Cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.badge,
                          color: Color(0xFF6B46C1),
                        ),
                      ),
                      title: const Text(
                        'User ID',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        userId.substring(0, 8).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFFECDD3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.security,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      title: const Text(
                        'Role',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                  onPressed: () => context.read<HttpDataService>().signOut(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
