class RescheduleModel {
  String? id; // Firestore document ID
  String classId; // Reference to the class
  String originalDate; // Original scheduled date (yyyy-MM-dd)
  String originalStartTime; // Original start time (HH:mm)
  String originalEndTime; // Original end time (HH:mm)
  String rescheduledDate; // New date (yyyy-MM-dd)
  String rescheduledStartTime; // New start time (HH:mm)
  String rescheduledEndTime; // New end time (HH:mm)
  String? reason; // Optional reason for rescheduling
  DateTime createdAt; // When this reschedule was created

  RescheduleModel({
    this.id,
    required this.classId,
    required this.originalDate,
    required this.originalStartTime,
    required this.originalEndTime,
    required this.rescheduledDate,
    required this.rescheduledStartTime,
    required this.rescheduledEndTime,
    this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RescheduleModel.fromJson(Map<String, dynamic> json, String docId) {
    return RescheduleModel(
      id: docId,
      classId: json['classId'] ?? '',
      originalDate: json['originalDate'] ?? '',
      originalStartTime: json['originalStartTime'] ?? '',
      originalEndTime: json['originalEndTime'] ?? '',
      rescheduledDate: json['rescheduledDate'] ?? '',
      rescheduledStartTime: json['rescheduledStartTime'] ?? '',
      rescheduledEndTime: json['rescheduledEndTime'] ?? '',
      reason: json['reason'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'originalDate': originalDate,
      'originalStartTime': originalStartTime,
      'originalEndTime': originalEndTime,
      'rescheduledDate': rescheduledDate,
      'rescheduledStartTime': rescheduledStartTime,
      'rescheduledEndTime': rescheduledEndTime,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
