// lib/ui/classes/classes_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/class_model.dart';
import '../../services/http_data_service.dart';
import 'class_detail_page.dart';
import 'enroll_class_page.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final Set<String> _hiddenClassKeys = {};

  String _classKey(ClassModel classModel) =>
      classModel.docId ?? '${classModel.id}_${classModel.section ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadHiddenClasses();
  }

  Future<void> _loadHiddenClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('hidden_classes') ?? [];
    setState(() {
      _hiddenClassKeys.addAll(saved);
    });
  }

  Future<void> _persistHidden() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_classes', _hiddenClassKeys.toList());
  }

  String _getNextClassInfo(
      ClassModel classModel, HttpDataService dataService) {
    if (classModel.selectedDays.isEmpty) return "Next Class: No schedule set";

    final now = DateTime.now();
    final today = now.weekday;
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final todayDateString = DateFormat('yyyy-MM-dd').format(now);

    // Check if today's attendance is already taken
    final todayAttendanceTaken = dataService.history.any((record) =>
        record.classId == classModel.docId && record.date == todayDateString);

    // Find next scheduled day (skip today if attendance is already taken)
    int startIndex = todayAttendanceTaken ? 1 : 0;

    for (int i = startIndex; i < 14; i++) {
      // Check 2 weeks ahead to find rescheduled classes
      final targetDate = now.add(Duration(days: i));
      final checkDay = (today + i - 1) % 7; // Convert to 0-6 (Mon-Sun)
      final dayName = dayNames[checkDay];
      final dateString = DateFormat('yyyy-MM-dd').format(targetDate);

      // Check if this date was rescheduled FROM (skip it)
      final wasRescheduledFrom = classModel.getRescheduleForDate(dateString);
      if (wasRescheduledFrom != null && wasRescheduledFrom.isNotEmpty) {
        continue; // Skip this date as it was rescheduled
      }

      // Check if originally scheduled OR rescheduled TO this date
      final isOriginallyScheduled = classModel.selectedDays.contains(dayName);
      final wasRescheduledTo = classModel.getRescheduledToDate(dateString);
      final hasClassThisDay = isOriginallyScheduled ||
          (wasRescheduledTo != null && wasRescheduledTo.isNotEmpty);

      if (hasClassThisDay) {
        if (i == 0) {
          return "Next Class: Today, ${DateFormat('MMM dd').format(targetDate)}";
        } else if (i == 1) {
          return "Next Class: Tomorrow, ${DateFormat('MMM dd').format(targetDate)}";
        } else {
          return "Next Class: ${DateFormat('EEEE, MMM dd').format(targetDate)}";
        }
      }
    }
    return "Next Class: No upcoming classes";
  }

  List<ClassModel> _sortClassesByRecency(
      List<ClassModel> classes, HttpDataService dataService) {
    final now = DateTime.now();
    final today = now.weekday;
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final todayDateString = DateFormat('yyyy-MM-dd').format(now);

    return List.from(classes)
      ..sort((a, b) {
        // Calculate days until next class for each (considering attendance taken)
        int daysUntilA = _getDaysUntilNextClass(
            a, today, dayNames, dataService, todayDateString);
        int daysUntilB = _getDaysUntilNextClass(
            b, today, dayNames, dataService, todayDateString);

        return daysUntilA.compareTo(daysUntilB);
      });
  }

  int _getDaysUntilNextClass(
      ClassModel classModel,
      int today,
      List<String> dayNames,
      HttpDataService dataService,
      String todayDateString) {
    if (classModel.selectedDays.isEmpty)
      return 999; // Put unscheduled classes last

    // Check if today's attendance is already taken
    final todayAttendanceTaken = dataService.history.any((record) =>
        record.classId == classModel.docId && record.date == todayDateString);

    // Start from today or tomorrow based on attendance status
    int startIndex = todayAttendanceTaken ? 1 : 0;
    final now = DateTime.now();

    for (int i = startIndex; i < 14; i++) {
      // Check 2 weeks ahead for rescheduled classes
      final targetDate = now.add(Duration(days: i));
      final checkDay = (today + i - 1) % 7;
      final dayName = dayNames[checkDay];
      final dateString = DateFormat('yyyy-MM-dd').format(targetDate);

      // Check if this date was rescheduled FROM (skip it)
      final wasRescheduledFrom = classModel.getRescheduleForDate(dateString);
      if (wasRescheduledFrom != null && wasRescheduledFrom.isNotEmpty) {
        continue; // Skip this date as it was rescheduled
      }

      // Check if originally scheduled OR rescheduled TO this date
      final isOriginallyScheduled = classModel.selectedDays.contains(dayName);
      final wasRescheduledTo = classModel.getRescheduledToDate(dateString);
      final hasClassThisDay = isOriginallyScheduled ||
          (wasRescheduledTo != null && wasRescheduledTo.isNotEmpty);

      if (hasClassThisDay) {
        return i;
      }
    }
    return 999;
  }

  String _getClassInitials(String className) {
    if (className.isEmpty) return '?';

    // Split by spaces and get first letter of each word
    final words = className.trim().split(' ');
    if (words.isEmpty) return '?';

    // Get first letter of first word
    String initials = words[0][0].toUpperCase();

    // If there's a second word, add its first letter
    if (words.length > 1) {
      initials += words[1][0].toUpperCase();
    }

    return initials;
  }

  Future<void> _confirmDeleteClass(BuildContext context, ClassModel enrolledClass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
            'This will remove ${enrolledClass.name} (${enrolledClass.section ?? ''}) and its data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _hiddenClassKeys.add(_classKey(enrolledClass));
    });
    await _persistHidden();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${enrolledClass.name} removed from view (not deleted from server)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // REFACTORED: Use Consumer to listen for changes
    return Consumer<HttpDataService>(
      builder: (context, dataService, child) {
        final sortedClasses =
            _sortClassesByRecency(dataService.classes, dataService);

        final visibleClasses = sortedClasses
            .where((c) => !_hiddenClassKeys.contains(_classKey(c)))
            .toList();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'assets/dtu_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            title: const Text('Your Classes'),
          ),
          body: visibleClasses.isEmpty
              ? const Center(
                  child: Text('No classes yet. Tap + to enroll a new class.'))
              : ListView.builder(
                  itemCount: visibleClasses.length,
                  itemBuilder: (_, i) {
                    final enrolledClass = visibleClasses[i];
                    final nextClassInfo =
                        _getNextClassInfo(enrolledClass, dataService);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          child: Text(
                            _getClassInitials(enrolledClass.name),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        title: Text(enrolledClass.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Code: ${enrolledClass.id}"),
                            Text(
                              nextClassInfo,
                              style: TextStyle(
                                color: nextClassInfo.contains("Today")
                                    ? Colors.green
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              ClassDetailPage(classModel: enrolledClass),
                        )),
                        onLongPress: () => _confirmDeleteClass(
                            context, enrolledClass),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EnrollClassPage()),
            ),
            tooltip: 'Enroll Class',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
