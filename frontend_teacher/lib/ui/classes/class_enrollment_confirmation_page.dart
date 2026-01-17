// lib/ui/classes/class_enrollment_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/class_model.dart';
import '../../services/http_data_service.dart';

class ClassEnrollmentConfirmationPage extends StatefulWidget {
  final ClassModel classModel;

  const ClassEnrollmentConfirmationPage({
    super.key,
    required this.classModel,
  });

  @override
  State<ClassEnrollmentConfirmationPage> createState() =>
      _ClassEnrollmentConfirmationPageState();
}

class _ClassEnrollmentConfirmationPageState
    extends State<ClassEnrollmentConfirmationPage> {
  bool _isEnrolling = false;

  Future<void> _confirmEnrollment() async {
    setState(() => _isEnrolling = true);

    try {
      // Use the HttpDataService to save the new class
      await context.read<HttpDataService>().enrollClass(widget.classModel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Class '${widget.classModel.name}' enrolled successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        // Pop all the way back to the main classes page
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      debugPrint("Error enrolling class: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error enrolling class: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  Color _avatarColor(String name) {
    final colors = Colors.primaries;
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return colors[hash % colors.length].shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text("Confirm Class Enrollment"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Information Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Information',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Subject Code', widget.classModel.id),
                    _buildInfoRow('Subject Name', widget.classModel.name),
                    _buildInfoRow('Section/Slot', widget.classModel.section),
                    if (widget.classModel.ltpPattern != null)
                      _buildInfoRow(
                          'LTP Pattern', widget.classModel.ltpPattern!),
                    if (widget.classModel.teacherType != null)
                      _buildInfoRow(
                          'Teacher Type', widget.classModel.teacherType!),
                    if (widget.classModel.practicalGroup != null)
                      _buildInfoRow(
                          'Practical Group', widget.classModel.practicalGroup!),
                    _buildInfoRow('Total Students',
                        '${widget.classModel.students.length}'),
                    const SizedBox(height: 16),
                    Text(
                      'Class Schedule:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    // Display the schedule
                    if (widget.classModel.schedule != null)
                      ...widget.classModel.schedule!.entries.map((entry) {
                        final day = entry.key;
                        final times = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Card(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.5),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    day,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${times['start']} - ${times['end']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList()
                    else
                      const Text('No schedule set',
                          style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Students List Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student List',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                    ),
                    const SizedBox(height: 16),
                    // Display the list of students from the parsed CSV
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.classModel.students.length,
                      itemBuilder: (context, index) {
                        final student = widget.classModel.students[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _avatarColor(student.name),
                            foregroundColor: Colors.white,
                            child: (student.photoUrl.isNotEmpty &&
                                    student.photoUrl.startsWith('http'))
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: student.photoUrl,
                                      imageBuilder: (context, imageProvider) =>
                                          Image(
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
                                      errorWidget: (context, url, error) =>
                                          Center(
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
                          title: Text(student.name),
                          subtitle: Text('Roll No: ${student.rno}'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isEnrolling ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isEnrolling ? null : _confirmEnrollment,
                    icon: _isEnrolling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_isEnrolling ? 'Enrolling...' : 'Confirm'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build information rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
