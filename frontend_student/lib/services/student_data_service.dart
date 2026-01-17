import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/class_model.dart';
import '../models/attendance_stats.dart';
//alsjifhlidhfas; fasdjfhsadlf asdlfjhasd;fhasdfjhasdifulhfuihlfadsljf

class GamificationStatus {
  final int level;
  final int totalSessions;
  final int attendedSessions;
  final double overallPercent;
  final bool isLoading;

  const GamificationStatus({
    required this.level,
    required this.totalSessions,
    required this.attendedSessions,
    required this.overallPercent,
    required this.isLoading,
  });
}
/// HTTP-based data service for student app
class StudentDataService extends ChangeNotifier {
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
  static const String _jwtKey = 'student_jwt_token';
  static const String _userKey = 'student_user_data';

  // State
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  String? _authError;
  List<ClassModel> _classes = [];
  String? _jwtToken;
  final Map<String, bool> _btEnabled = {};
  final Map<String, bool> _btPresent = {};
  bool _hasPhoto = true; // photo upload disabled; treat as present
  String? _photoUrl;
  bool _isCheckingPhoto = false;
  final Map<String, AttendanceStats> _attendanceCache = {};
  bool _isGamificationLoading = false;

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get authError => _authError;
  bool get isStudent => _currentUser?['role'] == 'student';
  List<ClassModel> get classes => _classes;
  bool btEnabledFor(String classId) => _btEnabled[classId] ?? false;
  bool btPresentFor(String classId) => _btPresent[classId] ?? false;
  bool get hasPhoto => _hasPhoto;
  String? get photoUrl => _photoUrl;
  bool get isCheckingPhoto => _isCheckingPhoto;
  bool get isGamificationLoading => _isGamificationLoading;
  GamificationStatus get gamificationStatus => _computeGamificationStatus();

  StudentDataService() {
    _init();
  }

  Future<void> _init() async {
    await _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final token = await _secureStorage.read(key: _jwtKey);
      final userJson = await _secureStorage.read(key: _userKey);

      if (token != null && userJson != null) {
        _jwtToken = token;
        _currentUser = jsonDecode(userJson);

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
        Uri.parse('$baseUrl/students/me/classes'),
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

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      debugPrint('Starting Google Sign-In for student...');

      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        debugPrint('User cancelled Google Sign-In');
        _authError = 'Sign-in cancelled';
        _isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint('Google Sign-In successful: ${account.email}');

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get Google ID token');
      }

      debugPrint('Obtained Google ID token');

      // Call student-specific auth endpoint
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google/student'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      debugPrint('Backend auth response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _jwtToken = data['token'];
        _currentUser = data['user'];

        await _secureStorage.write(key: _jwtKey, value: _jwtToken);
        await _secureStorage.write(
          key: _userKey,
          value: jsonEncode(_currentUser),
        );

        debugPrint('Authentication successful: ${_currentUser!['email']}');
        await loadData();
      } else if (response.statusCode == 403) {
        // Allow login even if not registered - just show no classes
        debugPrint('Email not registered, allowing login with no classes');
        _jwtToken = 'guest_token'; // Placeholder token
        _currentUser = {
          'email': account.email,
          'name': account.displayName ?? account.email,
          'role': 'student',
        };

        await _secureStorage.write(key: _jwtKey, value: _jwtToken);
        await _secureStorage.write(
          key: _userKey,
          value: jsonEncode(_currentUser),
        );

        debugPrint('Guest login successful: ${_currentUser!['email']}');
        // Don't call loadData() - user will see empty classes
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
    _attendanceCache.clear();
    _hasPhoto = false;
    await _secureStorage.delete(key: _jwtKey);
    await _secureStorage.delete(key: _userKey);
    notifyListeners();
  }

  void clearAuthError() {
    _authError = null;
    notifyListeners();
  }

  Future<void> loadData() async {
    if (_jwtToken == null) {
      debugPrint('No JWT token, skipping data load');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('Loading enrolled classes...');

      final response = await http.get(
        Uri.parse('$baseUrl/students/me/classes'),
        headers: _buildHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> classesJson = jsonDecode(response.body);
        _classes =
            classesJson.map((json) => ClassModel.fromJson(json)).toList();
        debugPrint('Loaded ${_classes.length} classes');

        // Fetch BT flags from sidecar
        await _fetchBtFlagsForClasses();
        await refreshGamification(forceRefresh: true);
      } else if (response.statusCode == 401) {
        debugPrint('Token expired, clearing session');
        await _clearSession();
        return;
      } else {
        debugPrint('Error loading classes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AttendanceStats?> getAttendanceStats(
    String classId, {
    bool forceRefresh = false,
    bool suppressErrors = false,
  }) async {
    if (_jwtToken == null) {
      throw Exception('Not authenticated');
    }

    if (!forceRefresh && _attendanceCache.containsKey(classId)) {
      return _attendanceCache[classId];
    }

    try {
      debugPrint('Loading attendance stats for class $classId...');

      final response = await http.get(
        Uri.parse('$baseUrl/students/me/classes/$classId/attendance'),
        headers: _buildHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = AttendanceStats.fromJson(data);
        _attendanceCache[classId] = stats;
        notifyListeners();
        return stats;
      } else if (response.statusCode == 401) {
        await _clearSession();
        throw Exception('Session expired. Please sign in again.');
      } else if (response.statusCode == 403) {
        throw Exception('You are not enrolled in this class');
      } else {
        throw Exception('Failed to load attendance stats');
      }
    } catch (e) {
      debugPrint('Error loading attendance stats: $e');
      if (suppressErrors) return null;
      rethrow;
    }
  }

  ClassModel? getClassById(String classId) {
    try {
      return _classes.firstWhere((c) => c.id == classId);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMyPhoto() async {
    // Photo handling disabled
    return {'has_photo': true, 'photo_url': null};
  }

  Future<void> checkPhotoStatus() async {
    // Photo handling disabled
    _hasPhoto = true;
    _photoUrl = null;
    _isCheckingPhoto = false;
    notifyListeners();
  }

  Future<String> uploadPhoto(String imagePath) async {
    // Photo upload disabled; simulate success
    _hasPhoto = true;
    _photoUrl = null;
    notifyListeners();
    return '';
  }

  // --- BT sidecar ---
  static const String _sidecarUrl = String.fromEnvironment(
    'BT_SIDECAR_URL',
    defaultValue:
        'https://dtu-aims-bt-sidecar-612272896050.asia-south1.run.app',
  );
  static const String _sidecarApiKey = String.fromEnvironment(
    'BT_SIDECAR_API_KEY',
    defaultValue: 'dtuAimsBTSidecar2026SecureKey',
  );

  Future<void> _fetchBtFlagsForClasses() async {
    for (final cls in _classes) {
      final classId = cls.id;
      try {
        final resp = await http.get(
          Uri.parse('$_sidecarUrl/bt-checkin/$classId'),
          headers: {'X-API-Key': _sidecarApiKey},
        );
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          _btEnabled[classId] = data['enabled'] == true;
        } else {
          _btEnabled[classId] = false;
        }
      } catch (_) {
        _btEnabled[classId] = false;
      }
    }
    notifyListeners();
  }

  // Mark present locally (no DB write)
  void markBtPresent(String classId) {
    _btPresent[classId] = true;
    notifyListeners();

    // Also notify sidecar for teacher visibility (per-class)
    final email = _currentUser?['email'] as String?;
    if (email != null) {
      _sendPresenceToSidecar(classId, email);
    }
  }

  Future<void> _sendPresenceToSidecar(String classId, String email) async {
    try {
      final url = Uri.parse('$_sidecarUrl/bt-checkin/$classId/present');
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _sidecarApiKey,
        },
        body: jsonEncode({'email': email, 'present': true}),
      );
      if (resp.statusCode >= 400) {
        debugPrint('Sidecar presence update failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Sidecar presence update error: $e');
    }
  }

  Future<void> refreshGamification({bool forceRefresh = false}) async {
    if (_jwtToken == null || _classes.isEmpty) {
      _attendanceCache.clear();
      notifyListeners();
      return;
    }

    if (_isGamificationLoading) return;

    _isGamificationLoading = true;
    notifyListeners();

    try {
      await Future.wait(_classes.map((cls) async {
        await getAttendanceStats(
          cls.id,
          forceRefresh: forceRefresh,
          suppressErrors: true,
        );
      }));
    } finally {
      _isGamificationLoading = false;
      notifyListeners();
    }
  }

  GamificationStatus _computeGamificationStatus() {
    int totalSessions = 0;
    int attendedSessions = 0;

    for (final stats in _attendanceCache.values) {
      if (stats.totalCount <= 0) continue; // skip classes with no sessions
      totalSessions += stats.totalCount;
      attendedSessions += stats.attendedCount;
    }

    final overallPercent =
        totalSessions > 0 ? (attendedSessions / totalSessions) * 100.0 : 0.0;

    int level = 1;
    if (totalSessions >= 10 && overallPercent >= 90) {
      level = 3;
    } else if (totalSessions >= 5 && overallPercent >= 70) {
      level = 2;
    }

    return GamificationStatus(
      level: level,
      totalSessions: totalSessions,
      attendedSessions: attendedSessions,
      overallPercent: overallPercent,
      isLoading: _isGamificationLoading,
    );
  }
}
