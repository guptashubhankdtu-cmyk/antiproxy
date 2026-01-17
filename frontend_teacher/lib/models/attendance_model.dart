class AttendanceModel {
  final String id; // Unique ID for the record, can be 'classId_date'
  final String classId;
  final String date; // Stored as 'YYYY-MM-DD'
  final Map<String, String> studentStatuses; // e.g., {'rollNo': 'Present'}
  final String?
      processedImagePath; // Path to the processed image (for face recognition)

  AttendanceModel({
    required this.id,
    required this.classId,
    required this.date,
    required this.studentStatuses,
    this.processedImagePath,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'],
      classId: json['classId'],
      date: json['date'],
      // Convert the map's keys and values to the correct types
      studentStatuses: Map<String, String>.from(json['studentStatuses']),
      processedImagePath: json['processedImagePath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classId': classId,
      'date': date,
      'studentStatuses': studentStatuses,
      'processedImagePath': processedImagePath,
    };
  }
}
