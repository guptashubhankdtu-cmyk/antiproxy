/// Model for student's attendance statistics in a class
class AttendanceStats {
  final String classId;
  final String className;
  final String classCode;
  final String section;
  final String studentName;
  final String rollNo;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final int totalCount;
  final double percentage;
  final List<AttendanceRecord> records;

  AttendanceStats({
    required this.classId,
    required this.className,
    required this.classCode,
    required this.section,
    required this.studentName,
    required this.rollNo,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    required this.totalCount,
    required this.percentage,
    this.records = const [],
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      classId: json['classId'],
      className: json['className'],
      classCode: json['classCode'],
      section: json['section'],
      studentName: json['studentName'],
      rollNo: json['rollNo'],
      presentCount: json['presentCount'],
      absentCount: json['absentCount'],
      lateCount: json['lateCount'],
      excusedCount: json['excusedCount'],
      totalCount: json['totalCount'],
      percentage: (json['percentage'] as num).toDouble(),
      records: (json['records'] as List<dynamic>?)
              ?.map((r) => AttendanceRecord.fromJson(r))
              .toList() ??
          [],
    );
  }

  String get displayName => '$classCode - $className';

  bool get hasGoodAttendance => percentage >= 75.0;

  int get attendedCount => presentCount + lateCount;
}

class AttendanceRecord {
  final String date; // ISO format
  final String status; // present, absent, late, excused
  final bool recognizedByAi;
  final double? similarityScore;

  AttendanceRecord({
    required this.date,
    required this.status,
    this.recognizedByAi = false,
    this.similarityScore,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      date: json['date'],
      status: json['status'],
      recognizedByAi: json['recognizedByAi'] ?? false,
      similarityScore: json['similarityScore'] != null
          ? (json['similarityScore'] as num).toDouble()
          : null,
    );
  }

  DateTime get dateTime => DateTime.parse(date);

  bool get isPresent => status == 'present' || status == 'late';
}
