import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/class_model.dart';
import '../../models/student_model.dart';
import 'student_detail_page.dart';

class StudentListPage extends StatelessWidget {
  final ClassModel classModel;
  final List<Map<String, dynamic>> studentStatsList;
  final bool defaultersOnly;

  const StudentListPage({
    super.key,
    required this.classModel,
    required this.studentStatsList,
    this.defaultersOnly = false,
  });

  Color _avatarColor(String name) {
    final colors = Colors.primaries;
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return colors[hash % colors.length].shade400;
  }

  @override
  Widget build(BuildContext context) {
    final listToShow = defaultersOnly
        ? studentStatsList.where((s) => s['percent'] < 75).toList()
        : studentStatsList;

    final title =
        defaultersOnly ? "Defaulter List (< 75%)" : "Full Student List";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${classModel.name} | Code: ${classModel.id} | Section: ${classModel.section}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: listToShow.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      defaultersOnly ? Icons.celebration : Icons.people_outline,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      defaultersOnly
                          ? "No defaulters found!"
                          : "No student data available.",
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Student list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: listToShow.length,
                    itemBuilder: (context, index) {
                      final studentData = listToShow[index];
                      final studentName = studentData['name'] as String? ?? '';
                      final studentRoll = studentData['roll'] as String? ?? '';
                      final studentPhotoUrl =
                          studentData['photoUrl'] as String? ?? '';
                      final studentPercent =
                          studentData['percent'] as int? ?? 0;
                      final present = studentData['present'] as int? ?? 0;
                      final total = studentData['total'] as int? ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        child: ListTile(
                          onTap: () {
                            // Find the student model from classModel
                            final student = classModel.students.firstWhere(
                              (s) => s.rno == studentRoll,
                              orElse: () => StudentModel(
                                rno: studentRoll,
                                name: studentName,
                                photoUrl: studentPhotoUrl,
                              ),
                            );

                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        StudentDetailPage(
                                  student: student,
                                  classModel: classModel,
                                  attendanceStats: studentData,
                                ),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOut;
                                  var tween =
                                      Tween(begin: begin, end: end).chain(
                                    CurveTween(curve: curve),
                                  );
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                    const Duration(milliseconds: 300),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: _avatarColor(studentName),
                            foregroundColor: Colors.white,
                            child: (studentPhotoUrl.isNotEmpty &&
                                    studentPhotoUrl.startsWith('http'))
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: studentPhotoUrl,
                                      imageBuilder: (context, imageProvider) =>
                                          Image(
                                        image: imageProvider,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      ),
                                      placeholder: (context, url) => Container(
                                        width: 44,
                                        height: 44,
                                        color: Colors.grey.shade200,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Center(
                                        child: Text(
                                          studentName.isNotEmpty
                                              ? studentName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    studentName.isNotEmpty
                                        ? studentName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          title: Text(
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            "Roll No: $studentRoll",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: studentPercent < 75
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  "$studentPercent%",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: studentPercent < 75
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$present/$total",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  // Widget _buildSummaryItem(
  //   BuildContext context,
  //   String label,
  //   String value,
  //   IconData icon,
  // ) {
  //   return Column(
  //     children: [
  //       Icon(
  //         icon,
  //         size: 32,
  //         color: Theme.of(context).colorScheme.primary,
  //       ),
  //       const SizedBox(height: 8),
  //       Text(
  //         value,
  //         style: Theme.of(context).textTheme.headlineSmall?.copyWith(
  //               fontWeight: FontWeight.bold,
  //               color: Theme.of(context).colorScheme.primary,
  //             ),
  //       ),
  //       const SizedBox(height: 4),
  //       Text(
  //         label,
  //         style: Theme.of(context).textTheme.bodySmall,
  //       ),
  //     ],
  //   );
  // }
}
