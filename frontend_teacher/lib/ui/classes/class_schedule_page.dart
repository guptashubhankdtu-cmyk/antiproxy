import 'package:flutter/material.dart';
import '../../models/class_model.dart';
import 'class_enrollment_confirmation_page.dart';

class ClassSchedulePage extends StatefulWidget {
  final ClassModel partialClassModel;

  const ClassSchedulePage({
    super.key,
    required this.partialClassModel,
  });

  @override
  State<ClassSchedulePage> createState() => _ClassSchedulePageState();
}

class _ClassSchedulePageState extends State<ClassSchedulePage> {
  // Sunday removed for regular scheduling (can still be used via reschedule flow)
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  // Generate 30-minute time slots from 8:00 AM to 6:00 PM
  final List<String> _timeSlots = List.generate(21, (index) {
    final totalMinutes = 8 * 60 + index * 30;
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  });

  final Map<String, bool> _selectedDays = {};
  final Map<String, String?> _startTimes = {};
  final Map<String, String?> _endTimes = {};

  @override
  void initState() {
    super.initState();
    for (var day in _daysOfWeek) {
      _selectedDays[day] = false;
      _startTimes[day] = null;
      _endTimes[day] = null;
    }
  }

  String _formatTime(String time24) {
    final parts = time24.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];

    if (hour == 0) {
      return '12:$minute AM';
    } else if (hour < 12) {
      return '$hour:$minute AM';
    } else if (hour == 12) {
      return '12:$minute PM';
    } else {
      return '${hour - 12}:$minute PM';
    }
  }

  String _getWeeklyHoursRequirement() {
    final ltpPattern = widget.partialClassModel.ltpPattern;
    final teacherType = widget.partialClassModel.teacherType;

    if (ltpPattern == '310') {
      if (teacherType == 'Lecture') {
        return 'LTP 3-1-0: You must schedule exactly 4 hours per week (3 hours Lecture + 1 hour Tutorial)';
      }
    } else if (ltpPattern == '301') {
      if (teacherType == 'Lecture') {
        return 'LTP 3-0-1: You must schedule exactly 3 hours per week (3 hours Lecture)';
      } else if (teacherType == 'Practical') {
        return 'LTP 3-0-1: You must schedule exactly 2 hours per week (1 Practical = 2 contact hours)';
      }
    }

    return 'Please schedule appropriate hours for your class';
  }

  void _proceedToConfirmation() {
    // Validate that at least one day is selected
    final selectedDaysList = _selectedDays.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedDaysList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    // Validate that all selected days have both start and end times
    for (var day in selectedDaysList) {
      if (_startTimes[day] == null || _endTimes[day] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please set start and end times for $day')),
        );
        return;
      }

      // Validate that start time is before end time
      final start = _startTimes[day]!;
      final end = _endTimes[day]!;

      // Parse time strings to minutes
      final startParts = start.split(':');
      final endParts = end.split(':');
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      if (startMinutes >= endMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Start time must be before end time for $day')),
        );
        return;
      }

      // Validate that class duration is either 1 or 2 hours
      final durationMinutes = endMinutes - startMinutes;
      if (durationMinutes != 60 && durationMinutes != 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Class duration for $day must be either 1 hour or 2 hours (current: ${durationMinutes} minutes)')),
        );
        return;
      }
    }

    // Calculate total weekly hours
    int totalWeeklyHours = 0;
    for (var day in selectedDaysList) {
      final start = _startTimes[day]!;
      final end = _endTimes[day]!;
      final startParts = start.split(':');
      final endParts = end.split(':');
      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final durationHours = (endMinutes - startMinutes) ~/ 60;
      totalWeeklyHours += durationHours;
    }

    // Validate total hours based on LTP pattern and teacher type
    final ltpPattern = widget.partialClassModel.ltpPattern;
    final teacherType = widget.partialClassModel.teacherType;

    String? hoursError;

    if (ltpPattern == '310') {
      // 3 Lectures + 1 Tutorial + 0 Practical = 4 hours for lecture teacher
      if (teacherType == 'Lecture' && totalWeeklyHours != 4) {
        hoursError =
            'For 3-1-0 pattern, Lecture teachers must schedule exactly 4 hours per week (3L + 1T). Currently: $totalWeeklyHours hours';
      }
    } else if (ltpPattern == '301') {
      // 3 Lectures + 0 Tutorial + 1 Practical
      if (teacherType == 'Lecture' && totalWeeklyHours != 3) {
        hoursError =
            'For 3-0-1 pattern, Lecture teachers must schedule exactly 3 hours per week. Currently: $totalWeeklyHours hours';
      } else if (teacherType == 'Practical' && totalWeeklyHours != 2) {
        hoursError =
            'For 3-0-1 pattern, Practical teachers must schedule exactly 2 hours per week (1P = 2 contact hours). Currently: $totalWeeklyHours hours';
      }
    }

    if (hoursError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hoursError),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Build schedule map
    final Map<String, Map<String, String>> schedule = {};
    for (var day in selectedDaysList) {
      schedule[day] = {
        'start': _startTimes[day]!,
        'end': _endTimes[day]!,
      };
    }

    // Create complete class model with schedule
    final completeClassModel = ClassModel(
      id: widget.partialClassModel.id,
      name: widget.partialClassModel.name,
      students: widget.partialClassModel.students,
      section: widget.partialClassModel.section,
      ltpPattern: widget.partialClassModel.ltpPattern,
      teacherType: widget.partialClassModel.teacherType,
      practicalGroup: widget.partialClassModel.practicalGroup,
      schedule: schedule,
    );

    // Navigate to confirmation page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ClassEnrollmentConfirmationPage(classModel: completeClassModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Set Class Schedule'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('Subject Code: ${widget.partialClassModel.id}',
                        style: const TextStyle(color: Colors.white)),
                    Text('Subject Name: ${widget.partialClassModel.name}',
                        style: const TextStyle(color: Colors.white)),
                    Text('Section: ${widget.partialClassModel.section}',
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Weekly Hours Requirement Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3B5998)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF64B5F6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getWeeklyHoursRequirement(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select days and set timings for each class:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ..._daysOfWeek.map((day) {
              final isSelected = _selectedDays[day] ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isSelected ? 4 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        title: Text(
                          day,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            _selectedDays[day] = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (isSelected) ...[
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start Time',
                                      style: TextStyle(fontSize: 12, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _startTimes[day],
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    hint: const Text('Select time', style: TextStyle(color: Colors.grey)),
                                    dropdownColor: Color(0xFF2D2D2D),
                                    style: const TextStyle(color: Colors.white),
                                    items: _timeSlots.map((time) {
                                      return DropdownMenuItem(
                                        value: time,
                                        child: Text(_formatTime(time)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _startTimes[day] = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('End Time',
                                      style: TextStyle(fontSize: 12, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _endTimes[day],
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    hint: const Text('Select time', style: TextStyle(color: Colors.grey)),
                                    dropdownColor: Color(0xFF2D2D2D),
                                    style: const TextStyle(color: Colors.white),
                                    items: _timeSlots.map((time) {
                                      return DropdownMenuItem(
                                        value: time,
                                        child: Text(_formatTime(time)),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _endTimes[day] = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _proceedToConfirmation,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
