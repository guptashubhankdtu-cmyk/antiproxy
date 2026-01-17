import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:developer' as developer;
import '../services/student_data_service.dart';
import 'photo_capture_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<StudentDataService>();
    final user = dataService.currentUser;
    final status = dataService.gamificationStatus;
    final String levelName;
    final String badgeAsset;
    switch (status.level) {
      case 3:
        levelName = 'Conqueror';
        badgeAsset = 'assets/gold.png';
        break;
      case 2:
        levelName = 'Ascendent';
        badgeAsset = 'assets/silver.png';
        break;
      default:
        levelName = 'Cadet';
        badgeAsset = 'assets/bronze.png';
        break;
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user data available')),
      );
    }

    final String name = user['name'] ?? user['email'] ?? 'Student';
    final String email = user['email'] ?? '';
    
    // Debug logging
    developer.log('Profile Page - hasPhoto: ${dataService.hasPhoto}, photoUrl: ${dataService.photoUrl}');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: Colors.grey[900],
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: dataService.hasPhoto &&
                                dataService.photoUrl != null &&
                                dataService.photoUrl!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: dataService.photoUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    debugPrint(
                                        'Error loading photo: $error, URL: $url');
                                    return Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white.withOpacity(0.7),
                                    );
                                  },
                                ),
                              )
                            : ClipOval(
                                child: Image.asset(
                                  badgeAsset,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                      Positioned(
                        bottom: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Image.asset(
                            badgeAsset,
                            width: 28,
                            height: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$name · $levelName',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

          // Gamification Card (moved from Home)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildGamificationCard(status),
          ),

            // Profile Information
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildInfoCard(
                    context,
                    'Name',
                    name,
                    Icons.person,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    context,
                    'Email',
                    email,
                    Icons.email,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    context,
                    'Photo Status',
                    dataService.hasPhoto ? 'Uploaded' : 'Not Uploaded',
                    Icons.camera_alt,
                    statusColor: dataService.hasPhoto ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ),

            // Update Photo Button
            if (dataService.hasPhoto)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Update Photo'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhotoCapturePage(),
                        ),
                      ).then((uploaded) {
                        if (uploaded == true) {
                          dataService.checkPhotoStatus();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Photo updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                  onPressed: () {
                    _showLogoutDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
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

  Widget _buildGamificationCard(GamificationStatus status) {
    final String badgeAsset;
    final String levelName;
    final Color accentColor;
    switch (status.level) {
      case 3:
        badgeAsset = 'assets/gold.png';
        levelName = 'Conqueror';
        accentColor = Colors.amber;
        break;
      case 2:
        badgeAsset = 'assets/silver.png';
        levelName = 'Ascendent';
        accentColor = Colors.blueGrey.shade200;
        break;
      default:
        badgeAsset = 'assets/bronze.png';
        levelName = 'Cadet';
        accentColor = Colors.orange.shade300;
        break;
    }

    final percent = status.overallPercent;
    final percentTo70 = (percent / 70).clamp(0, 1).toDouble();
    final percentTo90 = (percent / 90).clamp(0, 1).toDouble();
    final sessionsTo5 = (status.totalSessions / 5).clamp(0, 1).toDouble();
    final sessionsTo10 = (status.totalSessions / 10).clamp(0, 1).toDouble();

    TextStyle smallText(Color? c) =>
        TextStyle(color: c ?? Colors.grey[400], fontSize: 12);

    return Card(
      color: Colors.grey[900],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(badgeAsset, width: 80, height: 80),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${status.level} · $levelName',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Local gamification based on your attendance',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                if (status.isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Overall attendance: ${percent.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            Text(
              '${status.attendedSessions} of ${status.totalSessions} sessions attended',
              style: smallText(Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.flag, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Level 2 (Ascendent): 70%+ & 5+ sessions',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: percentTo70,
              minHeight: 8,
              backgroundColor: Colors.grey[800],
              color: Colors.orangeAccent,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text(
                'Progress to 70%: ${percent.toStringAsFixed(1)}% / 70%',
                style: smallText(Colors.grey[400]),
              ),
            ),
            LinearProgressIndicator(
              value: sessionsTo5,
              minHeight: 8,
              backgroundColor: Colors.grey[800],
              color: Colors.orange,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${status.totalSessions} / 5 sessions counted',
                style: smallText(Colors.grey[400]),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Level 3 (Conqueror): 90%+ & 10+ sessions',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: percentTo90,
              minHeight: 8,
              backgroundColor: Colors.grey[800],
              color: Colors.greenAccent,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text(
                'Progress to 90%: ${percent.toStringAsFixed(1)}% / 90%',
                style: smallText(Colors.grey[400]),
              ),
            ),
            LinearProgressIndicator(
              value: sessionsTo10,
              minHeight: 8,
              backgroundColor: Colors.grey[800],
              color: Colors.lightGreen,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${status.totalSessions} / 10 sessions counted',
                style: smallText(Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: statusColor ?? Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<StudentDataService>().signOut();
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

