/// Model for a class from student perspective
class ClassModel {
  final String id;
  final String code;
  final String name;
  final String section;
  final String? teacherType;
  final String? ltpPattern;
  final String? practicalGroup;
  final String teacherName;
  final String teacherEmail;
  final List<ScheduleEntry> schedule;
  final bool btCheckinEnabled;

  ClassModel({
    required this.id,
    required this.code,
    required this.name,
    required this.section,
    this.teacherType,
    this.ltpPattern,
    this.practicalGroup,
    required this.teacherName,
    required this.teacherEmail,
    this.schedule = const [],
    this.btCheckinEnabled = false,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      section: json['section'],
      teacherType: json['teacherType'],
      ltpPattern: json['ltpPattern'],
      practicalGroup: json['practicalGroup'],
      teacherName: json['teacherName'],
      teacherEmail: json['teacherEmail'],
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((s) => ScheduleEntry.fromJson(s))
              .toList() ??
          [],
      btCheckinEnabled: json['btCheckinEnabled'] == true,
    );
  }

  String get displayName => '$code - $name (Section $section)';

  String getDayName(int dayOfWeek) {
    const days = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return days[dayOfWeek] ?? 'Unknown';
  }
}

class ScheduleEntry {
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final String startTime; // HH:MM
  final String endTime; // HH:MM

  ScheduleEntry({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleEntry(
      dayOfWeek: json['dayOfWeek'],
      startTime: json['startTime'],
      endTime: json['endTime'],
    );
  }

  String getDayName() {
    const days = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return days[dayOfWeek] ?? 'Unknown';
  }
}
