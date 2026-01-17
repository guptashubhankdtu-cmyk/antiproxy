import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/class_model.dart';
import '../../models/attendance_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/local_data_service.dart';
import '../../services/pdf_service.dart';
import 'classes/swipe_attendance_page.dart';

class DailyAttendanceDetailPage extends StatefulWidget {
  final ClassModel classModel;
  final AttendanceModel attendanceRecord;

  const DailyAttendanceDetailPage({
    super.key,
    required this.classModel,
    required this.attendanceRecord,
  });

  @override
  State<DailyAttendanceDetailPage> createState() =>
      _DailyAttendanceDetailPageState();
}

class _DailyAttendanceDetailPageState extends State<DailyAttendanceDetailPage> {
  bool _isGeneratingPdf = false;

  void _showImageInFullScreen(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Recognized Image'),
          ),
          body: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.zero,
            minScale: 0.1,
            maxScale: 10.0,
            child: Center(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.white),
                        SizedBox(height: 16),
                        Text('Image not found',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      await PdfService.shareAttendanceReport(
        classModel: widget.classModel,
        attendanceRecord: widget.attendanceRecord,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _printPdf() async {
    setState(() => _isGeneratingPdf = true);

    try {
      await PdfService.printAttendanceReport(
        classModel: widget.classModel,
        attendanceRecord: widget.attendanceRecord,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Export Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.blue),
                title: const Text('Share as PDF'),
                subtitle:
                    const Text('Share the attendance report as a PDF file'),
                onTap: () {
                  Navigator.pop(context);
                  _exportToPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.print, color: Colors.orange),
                title: const Text('Print PDF'),
                subtitle: const Text('Print the attendance report'),
                onTap: () {
                  Navigator.pop(context);
                  _printPdf();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final totalStudents = widget.classModel.students.length;
    final presentCount = widget.attendanceRecord.studentStatuses.values
        .where((status) => status.toLowerCase() == 'present')
        .length;
    final absentCount = totalStudents - presentCount;
    final attendancePercent = totalStudents > 0
        ? (presentCount / totalStudents * 100).toStringAsFixed(1)
        : "0";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attendance - ${widget.attendanceRecord.date}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.classModel.name} | Code: ${widget.classModel.id} | Section: ${widget.classModel.section}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (_isGeneratingPdf)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export as PDF',
              onPressed: _showExportOptions,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SwipeAttendancePage(classModel: widget.classModel),
                    ),
                  );
                },
                icon: const Icon(Icons.swipe, size: 18),
                label: const Text('Swipe Attendance'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatBox(context,
                    label: "Present",
                    value: "$presentCount / $totalStudents",
                    color: Colors.green),
                const SizedBox(width: 12),
                _buildStatBox(context,
                    label: "Absent",
                    value: "$absentCount / $totalStudents",
                    color: Colors.red),
                const SizedBox(width: 12),
                _buildStatBox(context,
                    label: "Percentage",
                    value: "$attendancePercent%",
                    color: Colors.blue),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.attendanceRecord.processedImagePath != null) ...[
              GestureDetector(
                onTap: () => _showImageInFullScreen(
                    context, widget.attendanceRecord.processedImagePath!),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(
                          File(widget.attendanceRecord.processedImagePath!),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Image not found',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recognized Image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Divider(),
            const ListTile(
              title: Text("Student",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing:
                  Text("Status", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: widget.classModel.students.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final student = widget.classModel.students[index];
                  final status =
                      widget.attendanceRecord.studentStatuses[student.rno] ??
                          'absent';
                  final isPresent = status.toLowerCase() == 'present';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isPresent ? Colors.green.shade100 : Colors.red.shade100,
                      child: Text(
                        student.name.isNotEmpty
                            ? student.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: isPresent
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(student.name),
                    subtitle: Text('Roll: ${student.rno}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPresent
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isPresent
                                ? Colors.green.shade200
                                : Colors.red.shade200),
                      ),
                      child: Text(
                        isPresent ? 'Present' : 'Absent',
                        style: TextStyle(
                          color: isPresent
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build the statistic boxes at the top
  Widget _buildStatBox(BuildContext context,
      {required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
