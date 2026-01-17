import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/student_model.dart';
import '../../models/class_model.dart';

class StudentDetailPage extends StatelessWidget {
  final StudentModel student;
  final ClassModel classModel;
  final Map<String, dynamic>? attendanceStats;

  const StudentDetailPage({
    super.key,
    required this.student,
    required this.classModel,
    this.attendanceStats,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = attendanceStats?['present'] ?? 0;
    final total = attendanceStats?['total'] ?? 0;
    final percent = total > 0 ? (present / total * 100).round() : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Student Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${classModel.name} | Code: ${classModel.id} | Section: ${classModel.section}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with photo and name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: student.photoUrl.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: student.photoUrl,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Text(
                                      student.name.isNotEmpty
                                          ? student.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              student.name.isNotEmpty
                                  ? student.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Roll No: ${student.rno}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Attendance Stats (if available)
            if (attendanceStats != null)
              Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: percent >= 75
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            percent >= 75
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            color: percent >= 75 ? Colors.green : Colors.red,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attendance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      percent >= 75 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Present',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$present',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade200,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Total Classes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$total',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Personal Information Section
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Consolidated info items
                  if (student.program != null || student.spCode != null)
                    _buildInfoRow(
                      'Program',
                      '${student.program ?? 'N/A'} - ${student.spCode ?? 'N/A'}',
                    ),

                  if (student.semester != null)
                    _buildInfoRow('Semester', student.semester!),

                  if (student.status != null)
                    _buildInfoRow('Status', student.status!),

                  if (student.duration != null)
                    _buildInfoRow('Duration', student.duration!),

                  // Show message if no personal info
                  if (student.program == null &&
                      student.spCode == null &&
                      student.semester == null &&
                      student.status == null &&
                      student.duration == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No additional information available',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Contact Information Section
            if ((student.email != null && student.email!.isNotEmpty) ||
                (student.dtuEmail != null &&
                    student.dtuEmail!.isNotEmpty &&
                    student.dtuEmail!.toUpperCase() != 'NULL') ||
                (student.phone != null && student.phone!.isNotEmpty))
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.contact_page_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Personal Email
                    if (student.email != null && student.email!.isNotEmpty)
                      _buildContactRow(
                        context: context,
                        icon: Icons.email_outlined,
                        label: 'Personal Email',
                        value: student.email!,
                        onEmail: () => _sendEmail(student.email!),
                        onCopy: () =>
                            _copyToClipboard(context, student.email!, 'Email'),
                      ),

                    // DTU Email
                    if (student.dtuEmail != null &&
                        student.dtuEmail!.isNotEmpty &&
                        student.dtuEmail!.toUpperCase() != 'NULL')
                      _buildContactRow(
                        context: context,
                        icon: Icons.email_outlined,
                        label: 'DTU Email',
                        value: student.dtuEmail!,
                        onEmail: () => _sendEmail(student.dtuEmail!),
                        onCopy: () => _copyToClipboard(
                            context, student.dtuEmail!, 'DTU Email'),
                      ),

                    // Phone
                    if (student.phone != null && student.phone!.isNotEmpty)
                      _buildContactRow(
                        context: context,
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: student.phone!,
                        onCall: () => _makePhoneCall(student.phone!),
                        onCopy: () =>
                            _copyToClipboard(context, student.phone!, 'Phone'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCall,
    VoidCallback? onEmail,
    required VoidCallback onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCopy,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (onCall != null)
                IconButton(
                  onPressed: onCall,
                  icon: const Icon(Icons.phone),
                  tooltip: 'Call',
                  iconSize: 20,
                  color: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              if (onEmail != null)
                IconButton(
                  onPressed: onEmail,
                  icon: const Icon(Icons.email),
                  tooltip: 'Email',
                  iconSize: 20,
                  color: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
