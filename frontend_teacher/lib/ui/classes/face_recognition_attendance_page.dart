import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/class_model.dart';
import '../../models/attendance_model.dart';
import '../../models/recognition_result_model.dart';
import '../../services/api_service.dart';
import '../../services/http_data_service.dart';
import 'swipe_attendance_page.dart';
import 'attendance_orchestration_page.dart';

class FaceRecognitionAttendancePage extends StatefulWidget {
  final ClassModel classModel;
  final DateTime selectedDate;

  const FaceRecognitionAttendancePage({
    super.key,
    required this.classModel,
    required this.selectedDate,
  });

  @override
  State<FaceRecognitionAttendancePage> createState() =>
      _FaceRecognitionAttendancePageState();
}

class _FaceRecognitionAttendancePageState
    extends State<FaceRecognitionAttendancePage> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  String? _processedImagePath;
  List<RecognitionResultModel> _recognitionResults = [];
  Map<String, String> _studentStatuses = {};
  bool _manualAttendanceCompleted = false; // Track if manual attendance is done
  late DateTime _selectedDate;
  
  // Similarity threshold for face recognition (30%)
  static const double _similarityThreshold = 0.30;

  @override
  void initState() {
    super.initState();
    _initializeStudentStatuses();
    _selectedDate = widget.selectedDate;
  }

  void _initializeStudentStatuses() {
    // Initialize all students as absent
    debugPrint(
        'Initializing student statuses for ${widget.classModel.students.length} students');
    for (var student in widget.classModel.students) {
      _studentStatuses[student.rno] = 'absent';
      debugPrint('Initialized ${student.name} (${student.rno}) as absent');
    }
    debugPrint('Total initialized: ${_studentStatuses.length}');
  }

  Future<void> _pickImage() async {
    try {
      // Show options for camera, gallery, or test image
      final dynamic result = await showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.science),
                  title: const Text('Use Test Image (aims_fotu2.jpg)'),
                  onTap: () => Navigator.pop(context, 'test'),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      );

      if (result == null) return;

      if (result == 'test') {
        // Use the test image from assets
        try {
          debugPrint('Loading test image from assets...');
          final ByteData data = await DefaultAssetBundle.of(context)
              .load('assets/images/aims_fotu2.jpg');
          final List<int> bytes = data.buffer.asUint8List();
          debugPrint('Test image loaded, size: ${bytes.length} bytes');

          final tempDir = await Directory.systemTemp.createTemp();
          final testImageFile = File('${tempDir.path}/aims_fotu2.jpg');
          await testImageFile.writeAsBytes(bytes);
          debugPrint('Test image saved to: ${testImageFile.path}');

          await _processImage(testImageFile);
        } catch (e) {
          debugPrint('Error loading test image: $e');
          _showErrorDialog('Error loading test image: $e');
        }
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: result as ImageSource,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      _showErrorDialog('Error picking image: $e');
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _apiService.processImageForAttendance(imageFile);
      final processedImagePath = result.$1;
      final recognitionResults = result.$2;

      setState(() {
        _processedImagePath = processedImagePath;
        _recognitionResults = recognitionResults;
        _isProcessing = false;
      });

      // Update student statuses based on recognition results
      _updateStudentStatusesFromRecognition();

      // No info dialog - just update the student statuses silently
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorDialog('Error processing image: $e');
    }
  }

  void _updateStudentStatusesFromRecognition() {
    // Reset all students to absent first
    _initializeStudentStatuses();

    debugPrint('=== UPDATING STUDENT STATUSES FROM RECOGNITION ===');
    debugPrint('Recognition results: ${_recognitionResults.length}');
    debugPrint('Class students: ${widget.classModel.students.length}');

    // Print all recognition results
    for (int i = 0; i < _recognitionResults.length; i++) {
      final result = _recognitionResults[i];
      debugPrint(
          'Recognition $i: "${result.name}" (${(result.similarityScore * 100).toStringAsFixed(1)}%)');
    }

    // Print all class students
    debugPrint('Class students:');
    for (var student in widget.classModel.students) {
      debugPrint('  - ${student.name} (${student.rno})');
    }

    int matchedCount = 0;
    Set<String> matchedRollNumbers = {}; // Track already matched students

    // Mark recognized students as present (only if similarity >= threshold)
    for (var result in _recognitionResults) {
      // Check similarity threshold
      if (result.similarityScore < _similarityThreshold) {
        debugPrint(
            '✗ BELOW THRESHOLD: "${result.name}" (${(result.similarityScore * 100).toStringAsFixed(1)}% < ${(_similarityThreshold * 100).toStringAsFixed(0)}%)');
        continue;
      }
      
      bool found = false;
      final recognizedName = result.name.toLowerCase().trim();
      
      // Normalize recognized name (remove extra spaces, special chars)
      final normalizedRecognizedName = recognizedName
          .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special chars
          .replaceAll(RegExp(r'\s+'), ' '); // Normalize spaces

      // Strategy 1: Exact match
      for (var student in widget.classModel.students) {
        if (matchedRollNumbers.contains(student.rno)) continue; // Skip already matched
        
        final studentName = student.name.toLowerCase().trim();
        if (studentName == recognizedName) {
          debugPrint(
              '✓ EXACT MATCH: "${result.name}" -> ${student.name} (${student.rno})');
          _studentStatuses[student.rno] = 'present';
          matchedRollNumbers.add(student.rno);
          matchedCount++;
          found = true;
          break;
        }
      }

      // Strategy 2: Normalized match (handles extra spaces, special chars)
      if (!found) {
        for (var student in widget.classModel.students) {
          if (matchedRollNumbers.contains(student.rno)) continue;
          
          final normalizedStudentName = student.name.toLowerCase().trim()
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .replaceAll(RegExp(r'\s+'), ' ');
          
          if (normalizedStudentName == normalizedRecognizedName) {
            debugPrint(
                '✓ NORMALIZED MATCH: "${result.name}" -> ${student.name} (${student.rno})');
            _studentStatuses[student.rno] = 'present';
            matchedRollNumbers.add(student.rno);
            matchedCount++;
            found = true;
            break;
          }
        }
      }

      // Strategy 3: First name match (if recognized name is single word)
      if (!found && !recognizedName.contains(' ')) {
        for (var student in widget.classModel.students) {
          if (matchedRollNumbers.contains(student.rno)) continue;
          
          final studentFirstName = student.name.split(' ').first.toLowerCase().trim();
          if (studentFirstName == recognizedName) {
            debugPrint(
                '✓ FIRST NAME MATCH: "${result.name}" -> ${student.name} (${student.rno})');
            _studentStatuses[student.rno] = 'present';
            matchedRollNumbers.add(student.rno);
            matchedCount++;
            found = true;
            break;
          }
        }
      }

      // Strategy 4: Contains match (fallback for partial names)
      if (!found) {
        for (var student in widget.classModel.students) {
          if (matchedRollNumbers.contains(student.rno)) continue;
          
          final studentName = student.name.toLowerCase().trim();
          // Check if either name contains the other (must be significant match)
          if ((studentName.contains(recognizedName) && recognizedName.length >= 3) ||
              (recognizedName.contains(studentName) && studentName.length >= 3)) {
            debugPrint(
                '✓ PARTIAL MATCH: "${result.name}" -> ${student.name} (${student.rno})');
            _studentStatuses[student.rno] = 'present';
            matchedRollNumbers.add(student.rno);
            matchedCount++;
            found = true;
            break;
          }
        }
      }

      if (!found) {
        debugPrint('✗ NO MATCH: "${result.name}" not found in class roster');
      }
    }

    final aboveThreshold = _recognitionResults.where((r) => r.similarityScore >= _similarityThreshold).length;
    
    debugPrint('=== RECOGNITION UPDATE COMPLETE ===');
    debugPrint('Total recognition results: ${_recognitionResults.length}');
    debugPrint('Above threshold (${(_similarityThreshold * 100).toStringAsFixed(0)}%): $aboveThreshold');
    debugPrint('Matched students: $matchedCount');
    debugPrint('Unmatched recognitions: ${aboveThreshold - matchedCount}');
    debugPrint('Final student statuses: $_studentStatuses');
    debugPrint(
        'Present count: ${_studentStatuses.values.where((status) => status == 'present').length}');
    
    // Show snackbar with results
    if (mounted) {
      final presentCount = _studentStatuses.values.where((s) => s == 'present').length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Detected ${_recognitionResults.length} faces, matched $matchedCount students (threshold: ${(_similarityThreshold * 100).toStringAsFixed(0)}%)'),
          backgroundColor: matchedCount > 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImageInFullScreen(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Recognized Image'),
          ),
          body: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.zero,
            minScale: 0.1,
            maxScale: 10.0,
            child: Center(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.white),
                        SizedBox(height: 16),
                        Text('Image not found',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleStudentStatus(String rollNo) {
    setState(() {
      final currentStatus = _studentStatuses[rollNo] ?? 'absent';
      _studentStatuses[rollNo] =
          currentStatus == 'present' ? 'absent' : 'present';
    });
  }

  Future<void> _proceedToConfirmation() async {
    // Validate that an image has been uploaded and processed
    if (_processedImagePath == null || _processedImagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload an image before saving attendance'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Ensure we have student statuses initialized
    if (_studentStatuses.isEmpty) {
      _initializeStudentStatuses();
    }

    final presentCount =
        _studentStatuses.values.where((status) => status == 'present').length;

    if (_recognitionResults.isEmpty && presentCount == 0) {
      // For testing: Mark first few students as present if no recognition results
      debugPrint(
          'No recognition results and no present students. Marking first 3 students as present for testing.');
      for (int i = 0; i < widget.classModel.students.length && i < 3; i++) {
        final student = widget.classModel.students[i];
        _studentStatuses[student.rno] = 'present';
        debugPrint(
            'Marked ${student.name} (${student.rno}) as present for testing');
      }
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
        ),
      ),
    );

    try {
      // Debug: Print the data being saved
      debugPrint('=== SAVING ATTENDANCE ===');
      debugPrint('Class ID: ${widget.classModel.id}');
      debugPrint('Class name: ${widget.classModel.name}');
      debugPrint(
          'Total students in class: ${widget.classModel.students.length}');
      debugPrint('Student statuses map: $_studentStatuses');
      debugPrint('Student statuses count: ${_studentStatuses.length}');
      debugPrint('Present students: $presentCount');
      debugPrint('Recognition results: ${_recognitionResults.length}');

      // Verify the data structure
      for (var entry in _studentStatuses.entries) {
        debugPrint('Student ${entry.key}: ${entry.value}');
      }

      // Save attendance directly
      final attendanceRecord = AttendanceModel(
        id: '',
        classId: widget.classModel.docId!,
        date: _selectedDate.toIso8601String().split('T')[0],
        studentStatuses: Map<String, String>.from(_studentStatuses),
        processedImagePath: _processedImagePath,
      );

      await context
          .read<HttpDataService>()
          .saveAttendanceRecord(attendanceRecord);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Attendance saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Go back to class detail page
        Navigator.pop(context, true);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      debugPrint('Error saving attendance: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Face Recognition Attendance',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.classModel.name} | Code: ${widget.classModel.id} | Section: ${widget.classModel.section}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Image display section
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _processedImagePath != null
                      ? GestureDetector(
                          onTap: () => _showImageInFullScreen(
                              context, _processedImagePath!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Image.file(
                                  File(_processedImagePath!),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                // Overlay to indicate it's clickable
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No image selected',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the camera button to take a photo',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Student list section
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Student List (${widget.classModel.students.length})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (_recognitionResults.isNotEmpty)
                                        Text(
                                          '${_studentStatuses.values.where((s) => s == 'present').length} present • ${_recognitionResults.length} faces detected',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_month, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Date: ${_selectedDate.toIso8601String().split('T')[0]}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: widget.classModel.students.length,
                          itemBuilder: (context, index) {
                            final student = widget.classModel.students[index];
                            final status =
                                _studentStatuses[student.rno] ?? 'absent';
                            final isPresent = status == 'present';

                            // Find the recognition result for this student
                            RecognitionResultModel? recognitionResult;
                            try {
                              recognitionResult =
                                  _recognitionResults.firstWhere(
                                (result) =>
                                    result.name.toLowerCase().trim() ==
                                        student.name.toLowerCase().trim() ||
                                    student.name
                                        .toLowerCase()
                                        .contains(result.name.toLowerCase()) ||
                                    result.name
                                        .toLowerCase()
                                        .contains(student.name.toLowerCase()),
                              );
                            } catch (e) {
                              recognitionResult = null;
                            }

                            // Build subtitle with similarity percentage if recognized
                            String subtitle = 'Roll No: ${student.rno}';
                            if (recognitionResult != null) {
                              final similarityPercent =
                                  (recognitionResult.similarityScore * 100)
                                      .toStringAsFixed(1);
                              subtitle =
                                  'Roll No: ${student.rno} - ${similarityPercent}% match';
                            }

                            return ListTile(
                              key: ValueKey(student.rno),
                              leading: CircleAvatar(
                                radius: 20,
                                child: student.photoUrl.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: student.photoUrl,
                                          cacheManager: null,
                                          imageBuilder:
                                              (context, imageProvider) => Image(
                                            image: imageProvider,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                          ),
                                          placeholder: (context, url) =>
                                              Container(
                                            width: 40,
                                            height: 40,
                                            color: Colors.grey.shade200,
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Text(
                                            student.name.isNotEmpty
                                                ? student.name[0].toUpperCase()
                                                : '?',
                                          ),
                                        ),
                                      )
                                    : Text(student.name.isNotEmpty
                                        ? student.name[0].toUpperCase()
                                        : '?'),
                              ),
                              title: Text(student.name),
                              subtitle: Text(subtitle),
                              trailing: GestureDetector(
                                onTap: () => _toggleStudentStatus(student.rno),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        isPresent ? Colors.green : Colors.red,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isPresent ? Icons.check : Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPresent ? 'Present' : 'Absent',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: _processedImagePath == null ||
                        _processedImagePath!.isEmpty
                    ?
                    // Before photo upload: Show only "Take Photo" button
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: _isProcessing
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      )
                    :
                        // After photo upload: Show "Retake Photo", "Save Attendance", and "Confirm with Bluetooth"
                        Column(
                            children: [
                              // First row: Retake Photo (full width)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isProcessing ? null : _pickImage,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retake Photo'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Second row: Save Attendance and Confirm with Bluetooth
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing
                                          ? null
                                          : _proceedToConfirmation,
                                      icon: const Icon(Icons.save),
                                      label: const Text('Save'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing
                                          ? null
                                          : () {
                                              // Navigate to orchestration page with face recognition results
                                              Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      AttendanceOrchestrationPage(
                                                    classModel: widget.classModel,
                                                    initialStudentStatuses: _studentStatuses,
                                                    processedImagePath: _processedImagePath,
                                                  ),
                                                ),
                                              );
                                            },
                                      icon: const Icon(Icons.bluetooth_searching),
                                      label: const Text('+ Bluetooth'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
              ),
            ],
          ),
          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Processing Image...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Detecting faces and recognizing students',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        child: Text(
                          'This may take a few seconds',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
