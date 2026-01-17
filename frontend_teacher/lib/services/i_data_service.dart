import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';

/// Abstract data service interface.
///
/// This interface defines the contract that both FirebaseDataService
/// and HttpDataService must implement, ensuring the UI can work with
/// either backend seamlessly.
abstract class IDataService extends ChangeNotifier {
  // Authentication state
  Map<String, dynamic>? get currentUser;
  bool get isLoading;
  String? get authError;
  bool get isTeacher;
  bool get isAdmin;
  bool get isStudent;

  // Data
  List<ClassModel> get classes;
  List<AttendanceModel> get history;

  // Authentication methods
  Future<void> signInWithGoogle({bool forceAccountPicker = false});
  Future<void> signOut();
  void clearAuthError();
  void resetAuthState();

  // Data loading
  Future<void> loadData();

  // Class management
  Future<void> updateClassStudents(
    String classId,
    List<StudentModel> students,
  );

  // Attendance
  Future<void> saveAttendanceRecord(AttendanceModel attendance);

  // Utility
  Future<bool> isEmailAuthorized(String email);
}
