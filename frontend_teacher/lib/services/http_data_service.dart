import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import 'i_data_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Add this import at the top


/// HTTP-based data service that communicates with the FastAPI backend.
///
/// Replaces Firebase/Firestore with REST API calls to PostgreSQL-backed backend.
class HttpDataService extends ChangeNotifier implements IDataService {
  // Configuration
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Default to local laptop IP for easy device testing. Override with
    // --dart-define=API_BASE_URL=<url> when needed.
    defaultValue: 'https://dtu-aims-backend-612272896050.asia-south1.run.app',
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web Client ID from antiproxy-dtu GCP project (612272896050)
    serverClientId:
        '612272896050-gu0k89o9jrhleseadphcceg4jlbvmsp3.apps.googleusercontent.com',
  );


  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _jwtKey = 'backend_jwt_token';
  static const String _userKey = 'user_data';

  // State
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  String? _authError;
  List<ClassModel> _classes = [];
  List<AttendanceModel> _history = [];
  String? _jwtToken;

  // Getters
  @override
  Map<String, dynamic>? get currentUser => _currentUser;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get authError => _authError;

  @override
  bool get isTeacher => _currentUser?['role'] == 'teacher';

  @override
  bool get isAdmin => _currentUser?['role'] == 'admin';

  @override
  bool get isStudent => _currentUser?['role'] == 'student';

  @override
  List<ClassModel> get classes => _classes;

  @override
  List<AttendanceModel> get history => _history;

  HttpDataService() {
    _init();
  }

  Future<void> _init() async {
    // Try to restore session from secure storage
    await _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final token = await _secureStorage.read(key: _jwtKey);
      final userJson = await _secureStorage.read(key: _userKey);

      if (token != null && userJson != null) {
        _jwtToken = token;
        _currentUser = jsonDecode(userJson);

        // Verify token is still valid by calling /users/me
        final isValid = await _verifyToken();

        if (isValid) {
          debugPrint('Restored session for: ${_currentUser!['email']}');
          await loadData();
        } else {
          debugPrint('Stored token expired, clearing session');
          await _clearSession();
        }
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
      await _clearSession();
    }
  }

  Future<bool> _verifyToken() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: _buildHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> _buildHeaders({Map<String, String>? additional}) {
    final headers = {
      'Content-Type': 'application/json',
      ...?additional,
    };

    if (_jwtToken != null) {
      headers['Authorization'] = 'Bearer $_jwtToken';
    }

    return headers;
  }

  @override
  Future<void> signInWithGoogle({bool forceAccountPicker = false}) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      debugPrint('Starting Google Sign-In...');

      // Sign in with Google
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('User cancelled Google Sign-In');
        _authError = 'Sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint('Google Sign-In successful: ${account.email}');

      // Get Google ID token
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get Google ID token');
      }

      debugPrint('Obtained Google ID token');

      // Exchange Google token for backend JWT
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      debugPrint('Backend auth response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _jwtToken = data['token'];
        _currentUser = data['user'];

        // Store JWT and user data securely
        await _secureStorage.write(key: _jwtKey, value: _jwtToken);
        await _secureStorage.write(
          key: _userKey,
          value: jsonEncode(_currentUser),
        );

        debugPrint('Authentication successful: ${_currentUser!['email']}');

        // Load user data
        await loadData();
      } else if (response.statusCode == 403) {
        _authError =
            'Access denied. Your email is not authorized to access this system.';
        debugPrint('Authorization failed: Not whitelisted');
        await _googleSignIn.signOut();
      } else if (response.statusCode == 401) {
        _authError = 'Authentication failed. Please try again.';
        debugPrint('Authentication failed: Invalid token');
        await _googleSignIn.signOut();
      } else {
        _authError = 'Server error. Please try again later.';
        debugPrint('Server error: ${response.statusCode}');
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Error during sign-in: $e');
      _authError = 'Sign-in error: ${e.toString()}';
      await _googleSignIn.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _clearSession();
      debugPrint('Signed out successfully');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<void> _clearSession() async {
    _jwtToken = null;
    _currentUser = null;
    _authError = null;
    _classes.clear();
    _history.clear();
    await _secureStorage.delete(key: _jwtKey);
    await _secureStorage.delete(key: _userKey);
    notifyListeners();
  }

  @override
  void clearAuthError() {
    _authError = null;
    notifyListeners();
  }

  @override
  void resetAuthState() {
    _currentUser = null;
    _authError = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  Future<void> loadData() async {
    if (_jwtToken == null) {
      debugPrint('No JWT token, skipping data load');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('Loading classes from backend...');

      // GET /classes
      final classesResponse = await http.get(
        Uri.parse('$baseUrl/classes'),
        headers: _buildHeaders(),
      );

      debugPrint('GET /classes response status: ${classesResponse.statusCode}');
      
      if (classesResponse.statusCode == 200) {
        debugPrint('Response body: ${classesResponse.body.substring(0, classesResponse.body.length > 500 ? 500 : classesResponse.body.length)}...');
        final List<dynamic> classesJson = jsonDecode(classesResponse.body);
        debugPrint('Parsed ${classesJson.length} classes from JSON');
        
        _classes = classesJson.map((json) {
          try {
            return _parseClass(json);
          } catch (e, stackTrace) {
            debugPrint('Error parsing class: $e');
            debugPrint('Stack trace: $stackTrace');
            debugPrint('Class JSON: $json');
            rethrow;
          }
        }).toList();

        debugPrint('Successfully loaded ${_classes.length} classes');
      } else if (classesResponse.statusCode == 401) {
        debugPrint('Token expired, clearing session');
        await _clearSession();
        return;
      } else {
        debugPrint('Error loading classes: ${classesResponse.statusCode}');
        debugPrint('Response body: ${classesResponse.body}');
      }

      // Load attendance history for all classes
      debugPrint('Loading attendance history...');
      _history.clear();

      for (final classModel in _classes) {
        try {
          debugPrint(
              'Fetching attendance for class ${classModel.name} (${classModel.docId})...');
          final historyResponse = await http.get(
            Uri.parse(
                '$baseUrl/attendance/sessions?classId=${classModel.docId}'),
            headers: _buildHeaders(),
          );

          debugPrint(
              'Attendance response for ${classModel.name}: ${historyResponse.statusCode}');

          if (historyResponse.statusCode == 200) {
            final List<dynamic> sessionsJson = jsonDecode(historyResponse.body);

            for (var session in sessionsJson) {
              // Convert backend session format to AttendanceModel
              final Map<String, String> studentStatuses = {};

              if (session['statuses'] != null) {
                for (var status in session['statuses']) {
                  studentStatuses[status['rollNo']] = status['status'];
                }
              }

              _history.add(AttendanceModel(
                id: '${classModel.docId}_${session['sessionDate']}',
                date: session['sessionDate'],
                classId: classModel.docId!,
                studentStatuses: studentStatuses,
                processedImagePath: session['processedImageUrl'],
              ));
            }
          } else {
            debugPrint(
                'Failed to load attendance for ${classModel.name}: ${historyResponse.statusCode} - ${historyResponse.body}');
          }
        } catch (e) {
          debugPrint('Error loading history for ${classModel.name}: $e');
          // Continue loading other classes
        }
      }

      debugPrint('Loaded ${_history.length} attendance records');
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ClassModel _parseClass(Map<String, dynamic> json) {
    // Parse students
    final List<StudentModel> students = (json['students'] as List<dynamic>)
        .map((s) => StudentModel.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    // Parse schedule (convert backend format to ClassModel format)
    // Backend sends dayOfWeek as int (1=Monday, 7=Sunday), ClassModel expects day name strings
    final Map<String, Map<String, String>> schedule = {};
    if (json['schedule'] != null) {
      for (var sched in json['schedule']) {
        final dayName = _getDayNameFromNumber(sched['dayOfWeek']);
        schedule[dayName] = {
          'start': sched['start'],
          'end': sched['end'],
        };
      }
    }

    // Parse reschedules - keep as raw map list (ClassModel expects List<Map<String, dynamic>>)
    final List<Map<String, dynamic>>? reschedules = json['reschedules'] != null
        ? List<Map<String, dynamic>>.from(json['reschedules'])
        : null;

    return ClassModel(
      docId: json['id'], // Use backend ID as docId
      id: json['code'], // Subject code
      name: json['name'],
      section: json['section'],
      teacherType: json['teacherType'],
      ltpPattern: json['ltpPattern'],
      practicalGroup: json['practicalGroup'],
      students: students,
      schedule: schedule,
      reschedules: reschedules,
    );
  }

  @override
  Future<void> updateClassStudents(
    String classId,
    List<StudentModel> students,
  ) async {
    if (_jwtToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      debugPrint('Updating students for class $classId...');

      // Convert students to backend format
      final studentsJson = students.map((s) => s.toJson()).toList();

      // PUT /classes/{classId}/students
      final response = await http.put(
        Uri.parse('$baseUrl/classes/$classId/students'),
        headers: _buildHeaders(),
        body: jsonEncode({'students': studentsJson}),
      );

      if (response.statusCode == 200) {
        debugPrint('Updated students for class $classId');

        // Reload data to get updated roster
        await loadData();
      } else if (response.statusCode == 401) {
        debugPrint('Token expired');
        await _clearSession();
        throw Exception('Session expired. Please sign in again.');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to update this class');
      } else {
        debugPrint('Error updating students: ${response.statusCode}');
        throw Exception('Failed to update students');
      }
    } catch (e) {
      debugPrint('Error updating students: $e');
      rethrow;
    }
  }

  // Helper methods for individual student operations
  // These are convenience wrappers around updateClassStudents()

  Future<void> addStudentToClass(
    String classId,
    StudentModel student,
  ) async {
    final classModel = _classes.firstWhere((c) => c.docId == classId);
    final updatedStudents = List<StudentModel>.from(classModel.students)
      ..add(student);
    await updateClassStudents(classId, updatedStudents);
  }

  Future<void> updateStudentInClass(
    String classId,
    StudentModel updatedStudent,
  ) async {
    final classModel = _classes.firstWhere((c) => c.docId == classId);
    final updatedStudents = classModel.students.map((s) {
      return s.rno == updatedStudent.rno ? updatedStudent : s;
    }).toList();
    await updateClassStudents(classId, updatedStudents);
  }

  Future<void> removeStudentFromClass(
    String classId,
    String rollNumber,
  ) async {
    final classModel = _classes.firstWhere((c) => c.docId == classId);
    final updatedStudents =
        classModel.students.where((s) => s.rno != rollNumber).toList();
    await updateClassStudents(classId, updatedStudents);
  }

  @override
  Future<void> saveAttendanceRecord(AttendanceModel attendance) async {
    if (_jwtToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      debugPrint('Saving attendance record...');

      // Step 1: Create or get session
      // POST /attendance/sessions
      final sessionResponse = await http.post(
        Uri.parse('$baseUrl/attendance/sessions'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'classId': attendance.classId,
          'sessionDate': attendance.date,
          'processedImageUrl': attendance.processedImagePath,
        }),
      );

      if (sessionResponse.statusCode != 200) {
        throw Exception('Failed to create attendance session');
      }

      final sessionData = jsonDecode(sessionResponse.body);
      final String sessionId = sessionData['sessionId'];

      debugPrint('Created/got session: $sessionId');

      // Step 2: Update statuses
      // PUT /attendance/sessions/{sessionId}/statuses
      final List<Map<String, dynamic>> updates = [];

      attendance.studentStatuses.forEach((rollNo, status) {
        updates.add({
          'rollNo': rollNo,
          'status': status,
          'recognizedByAi': false,
          'similarityScore': null,
        });
      });

      final statusResponse = await http.put(
        Uri.parse('$baseUrl/attendance/sessions/$sessionId/statuses'),
        headers: _buildHeaders(),
        body: jsonEncode({'updates': updates}),
      );

      if (statusResponse.statusCode == 200) {
        debugPrint('Saved attendance for ${updates.length} students');

        // Reload data to update attendance history
        await loadData();
      } else {
        throw Exception('Failed to save attendance statuses');
      }
    } catch (e) {
      debugPrint('Error saving attendance: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isEmailAuthorized(String email) async {
    // This would require a new backend endpoint or we can skip it
    // For now, just return true (authorization happens during sign-in)
    return true;
  }

  // Additional helper methods for UI compatibility

  Map<String, dynamic> getStudentAttendanceStats(String classId) {
    // Return cached stats if available, otherwise empty
    // Stats are populated by calling loadStudentAttendanceStats()
    return _studentStatsCache[classId] ?? {};
  }

  // Cache for student attendance stats
  final Map<String, Map<String, dynamic>> _studentStatsCache = {};

  Future<void> loadStudentAttendanceStats(String classId) async {
    if (_jwtToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      debugPrint('Loading student attendance stats for class $classId...');

      final response = await http.get(
        Uri.parse('$baseUrl/stats/classes/$classId/students'),
        headers: _buildHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> statsData = jsonDecode(response.body);

        // Convert list to map keyed by student roll number
        final Map<String, dynamic> statsMap = {};
        for (var stat in statsData) {
          final rollNo = stat['rollNo'] as String;
          statsMap[rollNo] = {
            'present': stat['present'] ?? 0,
            'absent': stat['absent'] ?? 0,
            'late': stat['late'] ?? 0,
            'excused': stat['excused'] ?? 0,
            'total': stat['total'] ?? 0,
          };
        }

        _studentStatsCache[classId] = statsMap;
        debugPrint('Loaded stats for ${statsMap.length} students');
        notifyListeners();
      } else if (response.statusCode == 401) {
        await _clearSession();
        throw Exception('Session expired');
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      // Don't rethrow - stats are optional
    }
  }

  Future<ClassModel?> getClassById(String classId) async {
    // Find class in local cache
    try {
      return _classes.firstWhere((c) => c.docId == classId);
    } catch (e) {
      debugPrint('Class not found in cache: $classId');
      return null;
    }
  }

  Future<void> deleteClass(String classId) async {
    if (_jwtToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      debugPrint('Deleting class $classId...');
      final response = await http.delete(
        Uri.parse('$baseUrl/classes/$classId'),
        headers: _buildHeaders(),
      );

      if (response.statusCode == 204) {
        _classes.removeWhere((c) => c.docId == classId);
        notifyListeners();
      } else if (response.statusCode == 401) {
        await _clearSession();
        throw Exception('Session expired');
      } else {
        throw Exception('Failed to delete class (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error deleting class: $e');
      rethrow;
    }
  }

  Future<void> enrollClass(ClassModel classModel) async {
    if (_jwtToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      debugPrint('Creating new class: ${classModel.name}...');

      // Step 1: Create the class
      final classData = {
        'code': classModel.id,
        'name': classModel.name,
        'section': classModel.section,
        'ltp_pattern': classModel.ltpPattern,
        'teacher_type': classModel.teacherType,
        'practical_group': classModel.practicalGroup,
      };

      final createResponse = await http.post(
        Uri.parse('$baseUrl/classes'),
        headers: _buildHeaders(),
        body: jsonEncode(classData),
      );

      String classId;

      if (createResponse.statusCode == 201) {
        final responseData = jsonDecode(createResponse.body);
        classId = responseData['id'];
        debugPrint('Class created with ID: $classId');
      } else if (createResponse.statusCode == 409) {
        // Class already exists - parse the error to get class info or reload
        debugPrint('Class already exists, finding existing class...');

        // Reload data to get the existing class
        await loadData();

        // Find the class by code and section
        final existingClass = _classes.firstWhere(
          (c) => c.id == classModel.id && c.section == classModel.section,
          orElse: () =>
              throw Exception('Could not find existing class after reload'),
        );

        classId = existingClass.docId!;
        debugPrint('Found existing class with ID: $classId');
      } else {
        debugPrint('Failed to create class: ${createResponse.statusCode}');
        throw Exception('Failed to create class: ${createResponse.body}');
      }

      // Step 2: Add students to the class
      if (classModel.students.isNotEmpty) {
        debugPrint('Adding ${classModel.students.length} students...');
        await updateClassStudents(classId, classModel.students);
        debugPrint('Students added successfully');
      }

      // Step 3: Add schedule
      if (classModel.schedule != null && classModel.schedule!.isNotEmpty) {
        debugPrint('Adding schedule...');
        for (final entry in classModel.schedule!.entries) {
          final dayOfWeek = _getDayOfWeekNumber(entry.key);
          final scheduleData = {
            'day_of_week': dayOfWeek,
            'start_time': entry.value['start']! + ':00',
            'end_time': entry.value['end']! + ':00',
          };

          final scheduleResponse = await http.post(
            Uri.parse('$baseUrl/classes/$classId/schedules'),
            headers: _buildHeaders(),
            body: jsonEncode(scheduleData),
          );

          if (scheduleResponse.statusCode != 201) {
            debugPrint('Failed to add schedule for ${entry.key}');
          }
        }
        debugPrint('Schedule added successfully');
      }

      // Reload all data
      await loadData();
      debugPrint('Class enrollment complete');
    } catch (e) {
      debugPrint('Error enrolling class: $e');
      rethrow;
    }
  }

  int _getDayOfWeekNumber(String dayName) {
    const dayMap = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
      'Sunday': 7,
    };
    return dayMap[dayName] ?? 1;
  }

  String _getDayNameFromNumber(int dayNumber) {
    const dayNames = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return dayNames[dayNumber] ?? 'Monday';
  }

  Future<void> saveReschedule(dynamic reschedule) async {
    if (_jwtToken == null) {
      throw Exception('Not authenticated');
    }

    try {
      debugPrint('Saving class reschedule...');

      // Extract data - handle both Map and RescheduleModel
      final String classId;
      final String originalDate;
      final String rescheduledDate;
      final String startTime;
      final String endTime;
      final String reason;

      if (reschedule is Map) {
        classId = reschedule['classId'];
        originalDate = reschedule['originalDate'];
        rescheduledDate = reschedule['rescheduledDate'];
        startTime = reschedule['rescheduledStartTime'];
        endTime = reschedule['rescheduledEndTime'];
        reason = reschedule['reason'] ?? '';
      } else {
        // Assume it's RescheduleModel
        classId = reschedule.classId;
        originalDate = reschedule.originalDate;
        rescheduledDate = reschedule.rescheduledDate;
        startTime = reschedule.rescheduledStartTime;
        endTime = reschedule.rescheduledEndTime;
        reason = reschedule.reason ?? '';
      }

      // Format dates and times for API
      final body = {
        'original_date': originalDate.split(' ')[0], // YYYY-MM-DD
        'rescheduled_date': rescheduledDate.split(' ')[0],
        'rescheduled_start_time': _formatTimeOfDay(startTime),
        'rescheduled_end_time': _formatTimeOfDay(endTime),
        'reason': reason,
      };

      // POST /classes/{classId}/reschedules
      final response = await http.post(
        Uri.parse('$baseUrl/classes/$classId/reschedules'),
        headers: _buildHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        debugPrint('Reschedule saved successfully');
        // Reload data to update UI
        await loadData();
      } else if (response.statusCode == 401) {
        await _clearSession();
        throw Exception('Session expired. Please sign in again.');
      } else if (response.statusCode == 404) {
        throw Exception('Class not found or access denied');
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Unknown error';
        throw Exception('Failed to save reschedule: $error');
      }
    } catch (e) {
      debugPrint('Error saving reschedule: $e');
      rethrow;
    }
  }

  // Helper to format TimeOfDay to HH:MM:SS
  String _formatTimeOfDay(dynamic time) {
    if (time is String) return time;
    // Assume it's TimeOfDay or similar with hour/minute
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }
}
