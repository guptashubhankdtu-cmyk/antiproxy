import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/class_model.dart';
import '../../models/attendance_model.dart';
import '../../services/http_data_service.dart';

class AttendanceConfirmationPage extends StatefulWidget {
  final ClassModel classModel;
  final Map<String, String> initialAttendanceStatus;
  final String? processedImagePath;

  const AttendanceConfirmationPage({
    super.key,
    required this.classModel,
    required this.initialAttendanceStatus,
    this.processedImagePath,
  });

  @override
  State<AttendanceConfirmationPage> createState() =>
      _AttendanceConfirmationPageState();
}

class _AttendanceConfirmationPageState
    extends State<AttendanceConfirmationPage> {
  late Map<String, String> _attendanceStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _attendanceStatus = Map.from(widget.initialAttendanceStatus);
  }

  void _toggleStudentStatus(String rollNumber) {
    setState(() {
      final currentStatus = _attendanceStatus[rollNumber] ?? 'absent';
      _attendanceStatus[rollNumber] =
          currentStatus.toLowerCase() == 'present' ? 'absent' : 'present';
    });
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);

    try {
      final attendanceRecord = AttendanceModel(
        id: '',
        classId: widget.classModel.docId!,
        date: DateTime.now().toIso8601String().split('T')[0],
        studentStatuses: _attendanceStatus,
        processedImagePath: widget.processedImagePath,
      );

      await context
          .read<HttpDataService>()
          .saveAttendanceRecord(attendanceRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Go back to the class detail page (pop 2 levels: confirmation -> swipe -> class detail)
        Navigator.pop(context); // Pop confirmation page
        Navigator.pop(context); // Pop swipe page, back to class detail
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendanceStatus.values
        .where((status) => status.toLowerCase() == 'present')
        .length;
    final totalCount = widget.classModel.students.length;
    final absentCount = totalCount - presentCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.classModel.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Code: ${widget.classModel.id} | Section: ${widget.classModel.section}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    label: 'Present',
                    count: presentCount,
                    total: totalCount,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    label: 'Absent',
                    count: absentCount,
                    total: totalCount,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Student List Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text('Student', style: TextStyle(fontWeight: FontWeight.bold)),
                Spacer(),
                Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Student List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: widget.classModel.students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = widget.classModel.students[index];
                final status = _attendanceStatus[student.rno] ?? 'absent';
                final isPresent = status.toLowerCase() == 'present';

                return ListTile(
                  leading: CircleAvatar(
                    child: (student.photoUrl.isNotEmpty &&
                            student.photoUrl.startsWith('http'))
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: student.photoUrl,
                              cacheManager: null,
                              imageBuilder: (context, imageProvider) => Image(
                                image: imageProvider,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                              placeholder: (context, url) => Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey.shade200,
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(student.name.isNotEmpty
                                    ? student.name[0].toUpperCase()
                                    : '?'),
                              ),
                            ),
                          )
                        : Text(student.name.isNotEmpty
                            ? student.name[0].toUpperCase()
                            : '?'),
                  ),
                  title: Text(student.name,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('Roll: ${student.rno}'),
                  trailing: GestureDetector(
                    onTap: () => _toggleStudentStatus(student.rno),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPresent ? Icons.check : Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPresent ? 'Present' : 'Absent',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Action Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Attendance'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$label ($count/$total)',
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
