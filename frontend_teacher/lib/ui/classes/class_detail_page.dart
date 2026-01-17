import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/class_model.dart';
import '../../models/attendance_model.dart';
import '../../services/http_data_service.dart';
import '../../utils/holiday_config.dart';
import 'face_recognition_attendance_page.dart';
import '../../ui/daily_attendance_detail_page.dart';
import '../bluetooth_scan_page.dart';
import 'attendance_orchestration_page.dart';
import 'attendance_orchestration_page.dart';
import 'class_edit_page.dart';
import 'student_list_page.dart';
import 'reschedule_class_page.dart';
import 'swipe_attendance_page.dart';
// Note: The history_page.dart import is no longer needed here for now.

class ClassDetailPage extends StatefulWidget {
  final ClassModel classModel;
  const ClassDetailPage({super.key, required this.classModel});

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  DateTime _visibleMonth = DateTime.now();
  int _slideDirection = 0; // -1 for previous, 1 for next

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  Future<bool?> _launchFaceRecognitionAttendance() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FaceRecognitionAttendancePage(
              classModel: widget.classModel,
              selectedDate: DateTime.now(),
            ),
      ),
    );
    return result;
  }

  void _onDateTapped(DateTime date, AttendanceModel? record,
      {required bool isScheduled}) {
    final todayDate = DateTime.now();
    final todayOnly = DateTime(todayDate.year, todayDate.month, todayDate.day);
    final tappedOnly = DateTime(date.year, date.month, date.day);

    if (record != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DailyAttendanceDetailPage(
          classModel: widget.classModel,
          attendanceRecord: record,
        ),
      ));
      return;
    }

    if (!isScheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not a scheduled class day')),
      );
      return;
    }

    if (tappedOnly.isAfter(todayOnly)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot mark future attendance')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceOrchestrationPage(
          classModel: widget.classModel,
          selectedDate: tappedOnly,
        ),
      ),
    );
  }

  void _showStudentList({bool defaultersOnly = false}) {
    final dataService = context.read<HttpDataService>();
    final studentStatsMap =
        dataService.getStudentAttendanceStats(widget.classModel.docId!);

    // Convert map to list format
    List<Map<String, dynamic>> studentStatsList = [];
    for (final student in widget.classModel.students) {
      final stats = studentStatsMap[student.rno];
      if (stats != null) {
        final present = stats['present'] ?? 0;
        final total = stats['total'] ?? 0;
        final percent = total > 0 ? (present / total * 100).round() : 0;

        studentStatsList.add({
          'name': student.name,
          'roll': student.rno,
          'photoUrl': student.photoUrl,
          'present': present,
          'total': total,
          'percent': percent,
        });
      } else {
        // Add students with no attendance records
        studentStatsList.add({
          'name': student.name,
          'roll': student.rno,
          'photoUrl': student.photoUrl,
          'present': 0,
          'total': 0,
          'percent': 0,
        });
      }
    }

    // Navigate to full-page student list
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentListPage(
          classModel: widget.classModel,
          studentStatsList: studentStatsList,
          defaultersOnly: defaultersOnly,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<HttpDataService>();
    final attendanceRecords = dataService.history
        .where((h) => h.classId == widget.classModel.docId)
        .toList();
    final attendanceDates = attendanceRecords.map((rec) => rec.date).toSet();
    final studentStatsMap =
        dataService.getStudentAttendanceStats(widget.classModel.docId!);

    // Convert to list format for defaulter count
    int defaulterCount = 0;
    final totalClasses = attendanceRecords.length;
    final hasMinimumClasses = totalClasses >= 5;

    if (hasMinimumClasses) {
      for (final student in widget.classModel.students) {
        final stats = studentStatsMap[student.rno];
        if (stats != null) {
          final present = stats['present'] ?? 0;
          final total = stats['total'] ?? 0;
          final percent = total > 0 ? (present / total * 100) : 0;
          if (percent < 75) defaulterCount++;
        }
      }
    }

    final now = DateTime.now();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final hasAttendanceToday = attendanceDates.contains(today);

    final firstDayOfMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final firstWeekdayOfMonth = (firstDayOfMonth.weekday + 6) % 7;
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

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
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // View Student List and Edit Student List buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showStudentList(defaultersOnly: false),
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text(
                      'View Student List',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ClassEditPage(classModel: widget.classModel),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text(
                      'Edit Student List',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
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
                label: const Text(
                  'Swipe Attendance',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Reschedule Class button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RescheduleClassPage(
                        classModel: widget.classModel,
                      ),
                    ),
                  );
                  // Reload the class data from Firebase to get updated reschedules
                  if (mounted) {
                    final dataService = context.read<HttpDataService>();
                    final updatedClass = await dataService
                        .getClassById(widget.classModel.docId!);

                    if (updatedClass != null) {
                      // Replace the page with updated class model
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                ClassDetailPage(classModel: updatedClass),
                          ),
                        );
                      }
                    } else {
                      // Fallback: just rebuild with existing data
                      setState(() {});
                    }
                  }
                },
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text(
                  'Reschedule Class',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Total Classes and Defaulters stats
            Row(
              children: [
                Expanded(
                    child: _statBox(
                        label: "Total Classes",
                        value: "${attendanceRecords.length}")),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!hasMinimumClasses) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Minimum 5 classes required to access defaulters list. Current: $totalClasses',
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } else {
                        _showStudentList(defaultersOnly: true);
                      }
                    },
                    child: _statBox(
                        label: "Defaulters (<75%)",
                        value: hasMinimumClasses ? "$defaulterCount" : "N/A"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous Month',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _slideDirection = -1;
                      _visibleMonth = DateTime(
                          _visibleMonth.year, _visibleMonth.month - 1, 1);
                    });
                  },
                ),
                Text(
                  DateFormat.yMMMM().format(_visibleMonth),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Next Month',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _slideDirection = 1;
                      _visibleMonth = DateTime(
                          _visibleMonth.year, _visibleMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((day) => Text(day,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)))
                  .toList(),
            ),
            const Divider(),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -200) {
                    setState(() {
                      _slideDirection = 1;
                      _visibleMonth = DateTime(
                          _visibleMonth.year, _visibleMonth.month + 1, 1);
                    });
                  } else if (velocity > 200) {
                    setState(() {
                      _slideDirection = -1;
                      _visibleMonth = DateTime(
                          _visibleMonth.year, _visibleMonth.month - 1, 1);
                    });
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final currentKey = ValueKey(
                        '${_visibleMonth.year}-${_visibleMonth.month}');
                    final isIncoming = child.key == currentKey;
                    if (isIncoming) {
                      // New month slides in from the swipe direction
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(_slideDirection * 1.0, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        )),
                        child: child,
                      );
                    } else {
                      // Old month slides out opposite to the swipe direction
                      return SlideTransition(
                        position: Tween<Offset>(
                          // For outgoing child, animation runs in reverse (1.0 -> 0.0),
                          // so set begin as the target offset and end as zero to slide out.
                          begin: Offset(-_slideDirection * 1.0, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeIn,
                        )),
                        child: child,
                      );
                    }
                  },
                  child: GridView.builder(
                    key: ValueKey(
                        '${_visibleMonth.year}-${_visibleMonth.month}'),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7),
                    itemCount: daysInMonth + firstWeekdayOfMonth,
                    itemBuilder: (context, index) {
                      if (index < firstWeekdayOfMonth)
                        return const SizedBox.shrink();

                      final day = index - firstWeekdayOfMonth + 1;
                      final date = DateTime(
                          _visibleMonth.year, _visibleMonth.month, day);
                      final dateString = DateFormat('yyyy-MM-dd').format(date);
                      final dayName = DateFormat('EEEE').format(date);
                      final isHoliday = isPublicHoliday(date);
                      final isToday = date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;
                      final hasRecord = attendanceDates.contains(dateString);

                      // Check for reschedules
                      final wasRescheduledFrom =
                          widget.classModel.getRescheduleForDate(dateString);
                      final wasRescheduledTo =
                          widget.classModel.getRescheduledToDate(dateString);

                      // Original schedule check - check both selectedDays and schedule map directly
                      final isOriginallyScheduled = widget
                              .classModel.selectedDays
                              .contains(dayName) ||
                          (widget.classModel.schedule?.containsKey(dayName) ??
                              false);
                      final isScheduled = isOriginallyScheduled;

                      // Has a rescheduled class coming to this date
                      final hasRescheduledClass = wasRescheduledTo != null &&
                          wasRescheduledTo.isNotEmpty;

                      Color bgColor = Colors.transparent;
                      Border? border;
                      Widget? indicator;
                      final todayDate = DateTime(now.year, now.month, now.day);

                      // Priority 0: Holiday (blocked)
                      if (isHoliday) {
                        bgColor = Colors.grey.shade300;
                        border =
                            Border.all(color: Colors.grey.shade700, width: 1.5);
                        indicator = Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(Icons.block,
                              size: 10, color: Colors.grey.shade800),
                        );
                      }
                      // Priority 1: Attendance taken (always green regardless of reschedule)
                      else if (hasRecord) {
                        bgColor = Colors.green.shade100;
                        border = Border.all(
                            color: Colors.green.shade600, width: 1.5);
                      }
                      // Priority 2: Scheduled but missed (past date without attendance)
                      else if (isScheduled &&
                          !hasRecord &&
                          date.isBefore(todayDate) &&
                          (wasRescheduledFrom == null ||
                              wasRescheduledFrom.isEmpty)) {
                        bgColor = Colors.red.shade100;
                        border =
                            Border.all(color: Colors.red.shade600, width: 1.5);
                      }
                      // Priority 3: Rescheduled TO this date (makeup class)
                      else if (hasRescheduledClass) {
                        bgColor = Colors.orange.shade100;
                        border = Border.all(
                            color: Colors.orange.shade600, width: 1.5);
                        indicator = Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(Icons.schedule,
                              size: 8, color: Colors.orange.shade800),
                        );
                      }
                      // Priority 4: Rescheduled FROM this date (cancelled)
                      else if (wasRescheduledFrom != null &&
                          wasRescheduledFrom.isNotEmpty) {
                        bgColor = Colors.grey.shade200;
                        border =
                            Border.all(color: Colors.grey.shade500, width: 1.5);
                        indicator = Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(Icons.event_busy,
                              size: 8, color: Colors.grey.shade700),
                        );
                      }
                      // Priority 5: Future scheduled (no reschedule)
                      else if (isScheduled) {
                        border =
                            Border.all(color: Colors.blue.shade300, width: 1.2);
                      }

                      // Today indicator: blue filled circle overriding other fills
                      if (isToday && !hasRecord) {
                        bgColor = Theme.of(context).colorScheme.primary;
                        border = null;
                      }

                      // Text color rules: black for light backgrounds (green, red, orange, grey), white for dark/transparent
                      final bool isBlueFill =
                          isToday && !hasRecord; // today's blue chip
                      final bool hasLightBackground =
                          hasRecord || // green
                          (isScheduled && !hasRecord && date.isBefore(todayDate) && (wasRescheduledFrom == null || wasRescheduledFrom.isEmpty)) || // red
                          hasRescheduledClass || // orange
                          (wasRescheduledFrom != null && wasRescheduledFrom.isNotEmpty) || // grey
                          isHoliday; // holiday grey
                      final Color dayTextColor = isBlueFill
                          ? Colors.white
                          : hasLightBackground
                              ? Colors.black
                              : Colors.white;

                      return GestureDetector(
                        onTap: () {
                          if (isHoliday) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Holiday - no class scheduled'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          final record = hasRecord
                              ? attendanceRecords
                                  .firstWhere((rec) => rec.date == dateString)
                              : null;
                          _onDateTapped(date, record, isScheduled: isScheduled);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                            border: border,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  color: dayTextColor,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (indicator != null) indicator,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Calendar Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(Colors.green.shade600, 'Attended'),
                _buildLegendItem(Colors.red.shade600, 'Missed'),
                _buildLegendItem(Colors.blue.shade300, 'Scheduled'),
                _buildLegendItem(Colors.orange.shade600, 'Rescheduled To'),
                _buildLegendItem(Colors.grey.shade500, 'Rescheduled From'),
                _buildLegendItem(Colors.grey.shade700, 'Holiday'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasAttendanceToday
                    ? null
                    : () async {
                        // Launch combined attendance flow (Bluetooth + Face)
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AttendanceOrchestrationPage(
                              classModel: widget.classModel,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.event_note),
                label: Text(hasAttendanceToday
                    ? "ATTENDANCE COMPLETED"
                    : "TAKE ATTENDANCE"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  disabledBackgroundColor: Colors.grey.shade400,
                  disabledForegroundColor: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(8),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 4),
          // FIX: Wrapped the value Text in a FittedBox to prevent overflow
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
            color: color.withOpacity(0.3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ],
    );
  }
}
