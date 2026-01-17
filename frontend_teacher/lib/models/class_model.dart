import 'student_model.dart';

class ClassModel {
  final String? docId; // Firebase document ID (internal use only)
  final String id; // Subject Code (user-facing)
  final String name; // Subject Name
  final List<StudentModel> students;
  final String section; // Class Section/Slot (Required)
  final String? ltpPattern; // LTP pattern: '310' or '301'
  final String? teacherType; // 'Lecture' or 'Practical'
  final String? practicalGroup; // Group number if practical teacher
  final Map<String, Map<String, String>>?
      schedule; // {day: {start: 'HH:mm', end: 'HH:mm'}}
  final List<Map<String, dynamic>>?
      reschedules; // Array of reschedule overrides

  ClassModel({
    this.docId,
    required this.id,
    required this.name,
    this.students = const [],
    required this.section,
    this.ltpPattern,
    this.teacherType,
    this.practicalGroup,
    this.schedule,
    this.reschedules,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    var studentList = json['students'] as List? ?? [];
    List<StudentModel> students =
        studentList.map((i) => StudentModel.fromJson(i)).toList();

    Map<String, Map<String, String>>? schedule;
    if (json['schedule'] != null) {
      final scheduleData = json['schedule'] as Map<String, dynamic>;
      schedule = scheduleData.map((key, value) =>
          MapEntry(key, Map<String, String>.from(value as Map)));
    }

    List<Map<String, dynamic>>? reschedules;
    if (json['reschedules'] != null) {
      reschedules = List<Map<String, dynamic>>.from(json['reschedules']);
    }

    return ClassModel(
      docId: json['docId'], // Firebase document ID
      id: json['id'], // Subject Code
      name: json['name'],
      students: students,
      section: json['section'] ?? '',
      ltpPattern: json['ltpPattern'],
      teacherType: json['teacherType'],
      practicalGroup: json['practicalGroup'],
      schedule: schedule,
      reschedules: reschedules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Don't include docId in JSON - it's managed by Firebase
      'id': id, // Subject Code
      'name': name,
      'students': students.map((s) => s.toJson()).toList(),
      'section': section,
      'ltpPattern': ltpPattern,
      'teacherType': teacherType,
      'practicalGroup': practicalGroup,
      'schedule': schedule,
      'reschedules': reschedules,
    };
  }

  // Helper method to get selected days from schedule
  List<String> get selectedDays => schedule?.keys.toList() ?? [];

  // Helper method to check if a specific date has been rescheduled
  Map<String, dynamic>? getRescheduleForDate(String date) {
    if (reschedules == null || reschedules!.isEmpty) {
      return null;
    }

    try {
      return reschedules!.firstWhere(
        (r) => r['originalDate'] == date,
        orElse: () => {},
      );
    } catch (e) {
      return null;
    }
  }

  // Helper method to get effective schedule for a date (with reschedule override)
  Map<String, String>? getEffectiveScheduleForDate(
      String date, String dayName) {
    // Check if this date has been rescheduled
    final reschedule = getRescheduleForDate(date);

    if (reschedule != null && reschedule.isNotEmpty) {
      // This class has been rescheduled - return null to indicate it shouldn't appear
      return null;
    }

    // No reschedule, return the regular schedule
    return schedule?[dayName];
  }

  // Helper method to check if a date is a rescheduled-to date
  Map<String, dynamic>? getRescheduledToDate(String date) {
    if (reschedules == null || reschedules!.isEmpty) {
      return null;
    }

    try {
      return reschedules!.firstWhere(
        (r) => r['rescheduledDate'] == date,
        orElse: () => {},
      );
    } catch (e) {
      return null;
    }
  }
}
