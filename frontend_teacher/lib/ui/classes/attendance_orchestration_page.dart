import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/class_model.dart';
import '../../models/attendance_model.dart';
import '../../models/student_model.dart';
import '../../services/http_data_service.dart';
import '../bluetooth_scan_page.dart';
import 'face_recognition_attendance_page.dart';

class AttendanceOrchestrationPage extends StatefulWidget {
  final ClassModel classModel;
  final Map<String, String>? initialStudentStatuses; // From face recognition
  final String? processedImagePath; // From face recognition
  final DateTime? selectedDate; // From calendar selection
  
  const AttendanceOrchestrationPage({
    super.key, 
    required this.classModel,
    this.initialStudentStatuses,
    this.processedImagePath,
    this.selectedDate,
  });

  @override
  State<AttendanceOrchestrationPage> createState() =>
      _AttendanceOrchestrationPageState();
}

class _AttendanceOrchestrationPageState
    extends State<AttendanceOrchestrationPage> {
  bool bluetoothWindowOpen = false;
  bool faceCompleted = false;
  bool _btCheckinEnabled = false;
  final Map<String, bool> _bluetoothReady = {};
  final Map<String, bool> _faceReady = {};
  Set<String> _btPresentEmails = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize face ready status from initial recognition results
    for (final s in widget.classModel.students) {
      if (widget.initialStudentStatuses != null) {
        final status = widget.initialStudentStatuses![s.rno];
        _faceReady[s.rno] = (status == 'present');
        if (_faceReady[s.rno] == true) {
          faceCompleted = true; // Mark face as completed if any student recognized
        }
      } else {
        _faceReady[s.rno] = false;
      }
      _bluetoothReady[s.rno] = false;
    }
    _fetchBtCheckinFlag();
    _fetchBtPresent();
  }

  void _simulateBluetoothReady() {
    // no-op now; readiness will be driven by student app detection
  }

  void _markFaceReady() {
    setState(() {
      faceCompleted = true;
      for (final key in _faceReady.keys) {
        _faceReady[key] = true;
      }
    });
  }

  Color _dotColor(bool on, {bool isBluetooth = true}) {
    if (!on) return Colors.grey;
    return isBluetooth ? Colors.amber : Colors.green;
  }

  // --- Sidecar config ---
  static const String _sidecarUrl =
      String.fromEnvironment('BT_SIDECAR_URL',
          defaultValue:
              'https://dtu-aims-bt-sidecar-612272896050.asia-south1.run.app');
  static const String _sidecarApiKey =
      String.fromEnvironment('BT_SIDECAR_API_KEY',
          defaultValue: 'dtuAimsBTSidecar2026SecureKey');

  String get _classIdForBt => widget.classModel.docId ?? widget.classModel.id;

  Future<void> _fetchBtCheckinFlag() async {
    try {
      final resp = await http.get(
        Uri.parse('$_sidecarUrl/bt-checkin/$_classIdForBt'),
        headers: {'X-API-Key': _sidecarApiKey},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final enabled = data['enabled'] == true;
        setState(() {
          _btCheckinEnabled = enabled;
          bluetoothWindowOpen = enabled;
        });
      }
    } catch (_) {
      // silent fail; leave defaults
    }
  }

  Future<void> _fetchBtPresent() async {
    try {
      final resp = await http.get(
        Uri.parse('$_sidecarUrl/bt-checkin/$_classIdForBt/present'),
        headers: {'X-API-Key': _sidecarApiKey},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List<dynamic> emails = data['present'] ?? [];
        final lowerEmails = emails
            .whereType<String>()
            .map((e) => e.toLowerCase())
            .toSet();
        setState(() {
          _btPresentEmails = lowerEmails;
          for (final s in widget.classModel.students) {
            final email = s.email?.toLowerCase();
            final dtu = s.dtuEmail?.toLowerCase();
            if ((email != null && lowerEmails.contains(email)) ||
                (dtu != null && lowerEmails.contains(dtu))) {
              _bluetoothReady[s.rno] = true;
            }
          }
        });
      }
    } catch (_) {
      // ignore fetch errors
    }
  }

  Future<void> _setBtCheckinFlag(bool enabled) async {
    try {
      final resp = await http.put(
        Uri.parse('$_sidecarUrl/bt-checkin/$_classIdForBt'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _sidecarApiKey,
        },
        body: jsonEncode({'enabled': enabled}),
      );

      if (resp.statusCode == 200) {
        setState(() {
          _btCheckinEnabled = enabled;
          bluetoothWindowOpen = enabled;
        });
        if (enabled) {
          _fetchBtPresent();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Bluetooth check-in ${enabled ? 'enabled' : 'disabled'}'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to update BT check-in: ${resp.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating BT check-in: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.classModel.students;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh BT presence',
            onPressed: _fetchBtPresent,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BluetoothScanPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      minimumSize: const Size(0, 42),
                    ),
                    icon: const Icon(Icons.bluetooth_searching, size: 18),
                    label: const Text('Scan', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final newState = !bluetoothWindowOpen;
                      _setBtCheckinFlag(newState);
                      if (newState) {
                        _simulateBluetoothReady(); // mock: set all ready
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      minimumSize: const Size(0, 42),
                    ),
                    icon: Icon(
                      bluetoothWindowOpen ? Icons.bluetooth_disabled : Icons.bluetooth,
                      size: 18,
                    ),
                    label: Text(
                      bluetoothWindowOpen ? 'Disable' : 'Enable',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importCsvAttendance,
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      minimumSize: const Size(0, 42),
                    ),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('CSV', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FaceRecognitionAttendancePage(
                          classModel: widget.classModel,
                          selectedDate: widget.selectedDate ?? DateTime.now(),
                        ),
                  ),
                );
              },
              icon: const Icon(Icons.face_retouching_natural),
              label: const Text('Start Face Recognition'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Students',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = students[index];
                final btOn = _bluetoothReady[student.rno] ?? false;
                final faceOn = _faceReady[student.rno] ?? false;
                return ListTile(
                  title: Text(student.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(student.rno, style: TextStyle(color: Colors.grey[400])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusDot(
                        color: _dotColor(btOn, isBluetooth: true),
                        label: 'BT',
                      ),
                      const SizedBox(width: 8),
                      _StatusDot(
                        color: _dotColor(faceOn, isBluetooth: false),
                        label: 'Face',
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Save Attendance Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _saveAttendance();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.save),
                label: const Text('Save Attendance'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  

  Future<void> _importCsvAttendance() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );
      if (result == null) return;

      final file = result.files.single;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read file.')),
        );
        return;
      }

      final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
      List<List<dynamic>> rows;
      if (ext == 'xlsx') {
        final excel = Excel.decodeBytes(bytes);
        if (excel.tables.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('XLSX file has no sheets.')),
          );
          return;
        }
        final sheet = excel.tables.values.first;
        rows = sheet.rows
            .map((r) => r.map((c) => c?.value ?? '').toList())
            .toList();
      } else {
        final content = utf8.decode(bytes);
        rows = const CsvToListConverter(
          eol: '\n',
          shouldParseNumbers: false,
        ).convert(content);
      }

      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is empty.')),
        );
        return;
      }

      final header = rows.first
          .map((e) => e.toString().trim().toLowerCase())
          .toList();
      final emailIdx = header.indexWhere((h) => h == 'email');
      int presenceIdx = header.indexWhere((h) => h.startsWith('presence'));
      if (emailIdx == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV must include an Email column.')),
        );
        return;
      }
      if (presenceIdx == -1) {
        presenceIdx =
            (header.length > emailIdx + 1) ? emailIdx + 1 : header.length - 1;
      }

      final statuses = <String, String>{
        for (final s in widget.classModel.students) s.rno: 'absent'
      };
      int matched = 0;
      int presentCount = 0;
      int unmatched = 0;

      for (final row in rows.skip(1)) {
        if (emailIdx >= row.length) continue;
        final rawEmail = row[emailIdx]?.toString().trim().toLowerCase();
        if (rawEmail == null || rawEmail.isEmpty) continue;

        final presentVal = presenceIdx < row.length ? row[presenceIdx] : '';
        final isPresent = _isPresentValue(presentVal);

        final match = widget.classModel.students.firstWhere(
          (s) => s.email?.toLowerCase() == rawEmail || s.dtuEmail?.toLowerCase() == rawEmail,
          orElse: () => StudentModel(rno: '', name: '', photoUrl: ''),
        );

        if (match.rno.isNotEmpty) {
          matched += 1;
          statuses[match.rno] = isPresent ? 'present' : 'absent';
          if (isPresent) presentCount += 1;
        } else {
          unmatched += 1;
        }
      }

      await _showCsvConfirmation(
        Map<String, String>.from(statuses),
        matchedCount: matched,
        presentCount: presentCount,
        unmatchedCount: unmatched,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import CSV: $e')),
      );
    }
  }

  bool _isPresentValue(dynamic value) {
    final v = value?.toString().trim().toLowerCase();
    if (v == null) return false;
    return {
      'present',
      'yes',
      'y',
      'true',
      '1',
      'p',
    }.contains(v);
  }

  Future<void> _showCsvConfirmation(
    Map<String, String> initialStatuses, {
    required int matchedCount,
    required int presentCount,
    required int unmatchedCount,
  }) async {
    final students = widget.classModel.students;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final localStatuses = Map<String, String>.from(initialStatuses);
        return StatefulBuilder(
          builder: (ctx, setState) {
            final currentPresent =
                localStatuses.values.where((s) => s == 'present').length;
            void toggleAll(bool makePresent) {
              for (final s in students) {
                localStatuses[s.rno] = makePresent ? 'present' : 'absent';
              }
              setState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.upload_file),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CSV attendance',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => toggleAll(true),
                        child: const Text('Mark all present'),
                      ),
                      TextButton(
                        onPressed: () => toggleAll(false),
                        child: const Text('Mark all absent'),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Matched: $matchedCount • Present: $currentPresent (CSV: $presentCount) • Unmatched emails: $unmatchedCount',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[400]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: students.length,
                      itemBuilder: (ctx, i) {
                        final student = students[i];
                        final status = localStatuses[student.rno] ?? 'absent';
                        final isPresent = status == 'present';
                        return CheckboxListTile(
                          value: isPresent,
                          onChanged: (_) {
                            setState(() {
                              localStatuses[student.rno] =
                                  isPresent ? 'absent' : 'present';
                            });
                          },
                          title: Text(student.name),
                          subtitle: Text(student.rno),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _saveAttendanceFromStatuses(localStatuses);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save attendance'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveAttendanceFromStatuses(
    Map<String, String> statuses, {
    String? processedImagePath,
  }) async {
    final docId = widget.classModel.docId;
    if (docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class is not synced with the server yet.')),
      );
      return;
    }

    final presentCount = statuses.values.where((s) => s == 'present').length;
    if (presentCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students marked present. Please review before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );

    try {
      final attendanceRecord = AttendanceModel(
        id: '',
        classId: docId,
        date: (widget.selectedDate ?? DateTime.now())
            .toIso8601String()
            .split('T')[0],
        studentStatuses: statuses,
        processedImagePath: processedImagePath,
      );

      await context.read<HttpDataService>().saveAttendanceRecord(attendanceRecord);

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Attendance saved! $presentCount students present'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog

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

  Future<void> _saveAttendance() async {
    final Map<String, String> studentStatuses = {};

    for (final student in widget.classModel.students) {
      final faceOn = _faceReady[student.rno] ?? false;
      final btOn = _bluetoothReady[student.rno] ?? false;

      if (faceOn || (bluetoothWindowOpen && btOn)) {
        studentStatuses[student.rno] = 'present';
      } else {
        studentStatuses[student.rno] = 'absent';
      }
    }

    await _saveAttendanceFromStatuses(
      studentStatuses,
      processedImagePath: widget.processedImagePath,
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
