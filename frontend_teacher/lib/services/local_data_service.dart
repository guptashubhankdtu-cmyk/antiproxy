import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class LocalDataService with ChangeNotifier {
  static const _classesKey = 'enrolled_classes';
  static const _historyKey = 'attendance_history';
  // Image cache manager with 7 day stale period for better caching
  static final BaseCacheManager imageCacheManager = CacheManager(
    Config(
      'studentImageCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: 'studentImageCache'),
    ),
  );

  List<ClassModel> _classes = [];
  List<AttendanceModel> _history = [];

  List<ClassModel> get classes => _classes;
  List<AttendanceModel> get history => _history;

  LocalDataService() {
    loadData();
  }
  List<Map<String, dynamic>> getStudentAttendanceStats(String classId) {
    // Find all history records for this specific class
    final classHistory =
        _history.where((rec) => rec.classId == classId).toList();

    // Find the class to get the full student list
    final targetClass = _classes.firstWhere((c) => c.id == classId,
        orElse: () => ClassModel(id: '', name: '', section: ''));
    if (targetClass.id.isEmpty) return [];

    final stats = targetClass.students.map((student) {
      int totalClassesWithRecord = 0;
      int presentClasses = 0;

      for (var record in classHistory) {
        // Only count if the student has a status in this record
        if (record.studentStatuses.containsKey(student.rno)) {
          totalClassesWithRecord++;
          if (record.studentStatuses[student.rno]?.toLowerCase() == 'present') {
            presentClasses++;
          }
        }
      }

      double percentage = totalClassesWithRecord > 0
          ? (presentClasses / totalClassesWithRecord * 100)
          : 0.0;

      return {
        "name": student.name,
        "roll": student.rno,
        "percent": percentage.toInt(),
        "photoUrl": student.photoUrl,
      };
    }).toList();

    return stats;
  }

  Future<void> _prefetchStudentImages(List<StudentModel> students) async {
    final List<String> urls = students
        .map((s) => s.photoUrl)
        .where((u) => u.isNotEmpty && u.startsWith('http'))
        .toList();
    if (urls.isEmpty) return;

    final List<Future<void>> tasks = urls.map((url) async {
      try {
        // Check if already cached first
        final fileInfo = await imageCacheManager.getFileFromCache(url);
        if (fileInfo != null) return; // Already cached, skip

        // Download and cache with longer timeout
        await imageCacheManager
            .downloadFile(url)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // If download fails, try to get from cache anyway
        try {
          await imageCacheManager.getFileFromCache(url);
        } catch (_) {}
      }
    }).toList();

    try {
      await Future.wait(tasks, eagerError: false);
    } catch (_) {}
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final classesJson = prefs.getString(_classesKey);
    if (classesJson != null) {
      final List<dynamic> decoded = jsonDecode(classesJson);
      _classes = decoded.map((item) => ClassModel.fromJson(item)).toList();
    }

    final historyJson = prefs.getString(_historyKey);
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      _history = decoded.map((item) => AttendanceModel.fromJson(item)).toList();
    }

    // Preload all student images in background
    _preloadAllStudentImages();

    notifyListeners();
  }

  void _preloadAllStudentImages() {
    // Collect all unique student photo URLs
    final Set<String> allPhotoUrls = {};
    for (final classModel in _classes) {
      for (final student in classModel.students) {
        if (student.photoUrl.isNotEmpty &&
            student.photoUrl.startsWith('http')) {
          allPhotoUrls.add(student.photoUrl);
        }
      }
    }

    if (allPhotoUrls.isNotEmpty) {
      // Preload in background without blocking UI
      Future.microtask(() => _prefetchStudentImages(allPhotoUrls
          .map((url) => StudentModel(name: '', rno: '', photoUrl: url))
          .toList()));
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _classesKey, jsonEncode(_classes.map((c) => c.toJson()).toList()));
    await prefs.setString(
        _historyKey, jsonEncode(_history.map((h) => h.toJson()).toList()));
  }

  Future<void> enrollClass(ClassModel classModel) async {
    _classes.add(classModel);
    // Prefetch student images so avatars load instantly later
    await _prefetchStudentImages(classModel.students);
    await _saveData();
    notifyListeners();
  }

  Future<void> updateClassStudents({
    required String classId,
    required List<StudentModel> students,
  }) async {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index == -1) return;
    final existing = _classes[index];
    _classes[index] = ClassModel(
      id: existing.id,
      name: existing.name,
      students: students,
      section: existing.section,
      ltpPattern: existing.ltpPattern,
      teacherType: existing.teacherType,
      practicalGroup: existing.practicalGroup,
      schedule: existing.schedule,
    );
    await _saveData();
    notifyListeners();
  }

  Future<void> addStudentToClass({
    required String classId,
    required StudentModel student,
  }) async {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index == -1) return;
    final existing = _classes[index];
    final updated = List<StudentModel>.from(existing.students);
    // Avoid duplicate roll numbers
    if (updated.any((s) => s.rno == student.rno)) return;
    updated.add(student);
    _classes[index] = ClassModel(
      id: existing.id,
      name: existing.name,
      students: updated,
      section: existing.section,
      ltpPattern: existing.ltpPattern,
      teacherType: existing.teacherType,
      practicalGroup: existing.practicalGroup,
      schedule: existing.schedule,
    );
    // Prefetch new student's image if present
    await _prefetchStudentImages([student]);
    await _saveData();
    notifyListeners();
  }

  Future<void> removeStudentFromClass({
    required String classId,
    required String rollNumber,
  }) async {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index == -1) return;
    final existing = _classes[index];
    final updated =
        existing.students.where((s) => s.rno != rollNumber).toList();
    _classes[index] = ClassModel(
      id: existing.id,
      name: existing.name,
      students: updated,
      section: existing.section,
      ltpPattern: existing.ltpPattern,
      teacherType: existing.teacherType,
      practicalGroup: existing.practicalGroup,
      schedule: existing.schedule,
    );
    await _saveData();
    notifyListeners();
  }

  Future<void> updateStudentInClass({
    required String classId,
    required StudentModel student,
  }) async {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index == -1) return;
    final existing = _classes[index];
    final updated = existing.students
        .map((s) => s.rno == student.rno ? student : s)
        .toList();
    _classes[index] = ClassModel(
      id: existing.id,
      name: existing.name,
      students: updated,
      section: existing.section,
      ltpPattern: existing.ltpPattern,
      teacherType: existing.teacherType,
      practicalGroup: existing.practicalGroup,
      schedule: existing.schedule,
    );
    // Prefetch possibly new/updated photo
    await _prefetchStudentImages([student]);
    await _saveData();
    notifyListeners();
  }

  // This method is for the old photo-based history. We can leave it for now.
  Future<String> saveAttendancePhoto(File photo, String classId) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final newPath = p.join(directory.path, fileName);
    await photo.copy(newPath);
    return newPath;
  }

  // REFACTORED: This method now matches the new date-centric AttendanceModel
  Future<void> saveAttendanceRecord({
    required String classId,
    required Map<String, String> studentStatuses,
    String? processedImagePath,
  }) async {
    final today = DateTime.now();
    final dateString = DateFormat('yyyy-MM-dd').format(today);
    final recordId = '${classId}_$dateString';

    // Debug logging
    debugPrint('LocalDataService: Saving attendance record');
    debugPrint('Class ID: $classId');
    debugPrint('Date: $dateString');
    debugPrint('Record ID: $recordId');
    debugPrint('Student statuses received: $studentStatuses');
    debugPrint('Number of students: ${studentStatuses.length}');

    final record = AttendanceModel(
      id: recordId,
      classId: classId,
      date: dateString,
      studentStatuses: studentStatuses,
      processedImagePath: processedImagePath,
    );

    // Remove any existing record for the same class on the same day to avoid duplicates
    _history.removeWhere((h) => h.id == recordId);
    _history.insert(0, record);

    debugPrint(
        'Record saved to history. Total history records: ${_history.length}');
    debugPrint('Latest record: ${record.toJson()}');

    await _saveData();
    notifyListeners();
  }
}
