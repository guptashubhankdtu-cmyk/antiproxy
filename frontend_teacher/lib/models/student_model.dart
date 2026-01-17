class StudentModel {
  final String rno;
  final String name;
  final String photoUrl;

  // Additional fields from Excel
  final String? program; // e.g., "BTECH"
  final String? spCode; // e.g., "BT", "CE", "CS"
  final String? semester; // e.g., "5"
  final String? status; // e.g., "Regular"
  final String? duration; // e.g., "NOV 2025"
  final String? email;
  final String? dtuEmail;
  final String? phone;

  StudentModel({
    required this.rno,
    required this.name,
    required this.photoUrl,
    this.program,
    this.spCode,
    this.semester,
    this.status,
    this.duration,
    this.email,
    this.dtuEmail,
    this.phone,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      rno: json['rollNo'] ?? json['rno'] ?? '', // Backend sends 'rollNo'
      name: json['name'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      program: json['program'],
      spCode: json['spCode'],
      semester: json['semester']?.toString(), // Convert int to String
      status: json['status'],
      duration: json['duration'],
      email: json['email'],
      dtuEmail: json['dtuEmail'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rollNo': rno, // Backend expects 'rollNo' (camelCase)
      'name': name,
      'photoUrl': photoUrl,
      if (program != null) 'program': program,
      if (spCode != null) 'spCode': spCode,
      if (semester != null) 'semester': semester,
      if (status != null) 'status': status,
      if (duration != null) 'duration': duration,
      if (email != null) 'email': email,
      if (dtuEmail != null) 'dtuEmail': dtuEmail,
      if (phone != null) 'phone': phone,
    };
  }
}
