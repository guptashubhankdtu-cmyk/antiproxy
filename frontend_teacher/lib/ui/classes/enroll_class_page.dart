import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../../models/student_model.dart';
import '../../models/class_model.dart';
import 'class_schedule_page.dart';

class EnrollClassPage extends StatefulWidget {
  const EnrollClassPage({super.key});

  @override
  State<EnrollClassPage> createState() => _EnrollClassPageState();
}

class _EnrollClassPageState extends State<EnrollClassPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectCodeCtrl = TextEditingController();
  final TextEditingController _subjectNameCtrl = TextEditingController();
  final TextEditingController _sectionCtrl = TextEditingController();
  final TextEditingController _practicalGroupCtrl = TextEditingController();
  String? _pickedPath;
  String? _fileName;
  String? _ltpPattern;
  String? _teacherType;

  // This function is now the "Next" button's action
  Future<void> _proceedToSchedule() async {
    if (!_formKey.currentState!.validate() || _pickedPath == null) {
      String errorMessage = "Please complete all fields.";
      if (_pickedPath == null) {
        errorMessage = "Please select a CSV or Excel file.";
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    // Validate LTP pattern selection
    if (_ltpPattern == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select LTP pattern")));
      return;
    }

    // Validate teacher type selection only if LTP is 3L/0T/2P (301)
    if (_ltpPattern == '301' && _teacherType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select teacher type")));
      return;
    }

    // Validate practical group if practical teacher
    if (_teacherType == 'Practical' &&
        _practicalGroupCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter practical group number")));
      return;
    }

    try {
      final file = File(_pickedPath!);
      final fileName = _fileName!.toLowerCase();

      List<StudentModel> students = [];

      if (fileName.endsWith('.csv')) {
        // Handle CSV files
        students = await _parseCSVFile(file);
      } else if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) {
        // Handle Excel files
        students = await _parseExcelFile(file);
      } else {
        throw Exception(
            "Unsupported file format. Please select a CSV or Excel file.");
      }

      if (students.isEmpty)
        throw Exception("No valid student data found in the file.");

      // Create partial class model (without schedule yet)
      final partialClassModel = ClassModel(
        id: _subjectCodeCtrl.text.trim(),
        name: _subjectNameCtrl.text.trim(),
        students: students,
        section: _sectionCtrl.text.trim(),
        ltpPattern: _ltpPattern,
        teacherType: _teacherType,
        practicalGroup: _teacherType == 'Practical'
            ? _practicalGroupCtrl.text.trim()
            : null,
      );

      // Navigate to schedule page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ClassSchedulePage(partialClassModel: partialClassModel),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error processing file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedPath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<List<StudentModel>> _parseCSVFile(File file) async {
    final content = utf8.decode(await file.readAsBytes());
    final rows = const CsvToListConverter(eol: '\n', fieldDelimiter: ',')
        .convert(content);

    if (rows.isEmpty) throw Exception("CSV file is empty.");

    final header =
        rows.first.map((e) => e.toString().toLowerCase().trim()).toList();

    // Map common column variations to our expected fields
    int? nameIndex, rollIndex, photoIndex;
    int? programIndex, spCodeIndex, semesterIndex, statusIndex, durationIndex;
    int? emailIndex, dtuEmailIndex, phoneIndex;

    for (int i = 0; i < header.length; i++) {
      final col = header[i];

      // Map name columns
      if (col == 'name' ||
          col == 'fullname' ||
          col == 'student_name' ||
          col == 'full_name') {
        nameIndex = i;
      }
      // Map roll number columns
      else if (col == 'rollno' ||
          col == 'roll_no' ||
          col == 'roll' ||
          col == 'rollnumber' ||
          col == 'roll_number') {
        rollIndex = i;
      }
      // Map photo URL columns
      else if (col == 'photourl' ||
          col == 'photo_url' ||
          col == 'photo' ||
          col == 'image_url' ||
          col == 'picture') {
        photoIndex = i;
      }
      // Additional fields from Excel format
      else if (col == 'aprog' || col == 'program') {
        programIndex = i;
      } else if (col == 'sp_code' || col == 'spcode') {
        spCodeIndex = i;
      } else if (col == 'semester' || col == 'sem') {
        semesterIndex = i;
      } else if (col == 'status') {
        statusIndex = i;
      } else if (col == 'duration') {
        durationIndex = i;
      } else if (col == 'email') {
        emailIndex = i;
      } else if (col == 'dtu_email' || col == 'dtuemail') {
        dtuEmailIndex = i;
      } else if (col == 'phone' || col == 'mobile') {
        phoneIndex = i;
      }
    }

    // Check required columns (name and roll are mandatory)
    if (nameIndex == null || rollIndex == null) {
      final availableColumns = header.where((h) => h.isNotEmpty).join(', ');
      throw Exception(
          "Required columns not found. Looking for 'name/fullname' and 'rollno/roll_no' columns.\n"
          "Available columns: $availableColumns\n"
          "Supported name columns: name, fullname, student_name, full_name\n"
          "Supported roll columns: rollno, roll_no, roll, rollnumber, roll_number");
    }

    final List<StudentModel> students = [];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= nameIndex || row.length <= rollIndex) continue;

      final name = row[nameIndex].toString().trim();
      final rollno = row[rollIndex].toString().trim();
      final photoUrl = photoIndex != null && photoIndex < row.length
          ? row[photoIndex].toString().trim()
          : '';

      if (name.isEmpty || rollno.isEmpty) continue;

      students.add(StudentModel(
        rno: rollno,
        name: name,
        photoUrl: photoUrl,
        program: programIndex != null && programIndex < row.length
            ? row[programIndex].toString().trim()
            : null,
        spCode: spCodeIndex != null && spCodeIndex < row.length
            ? row[spCodeIndex].toString().trim()
            : null,
        semester: semesterIndex != null && semesterIndex < row.length
            ? row[semesterIndex].toString().trim()
            : null,
        status: statusIndex != null && statusIndex < row.length
            ? row[statusIndex].toString().trim()
            : null,
        duration: durationIndex != null && durationIndex < row.length
            ? row[durationIndex].toString().trim()
            : null,
        email: emailIndex != null && emailIndex < row.length
            ? row[emailIndex].toString().trim()
            : null,
        dtuEmail: dtuEmailIndex != null && dtuEmailIndex < row.length
            ? row[dtuEmailIndex].toString().trim()
            : null,
        phone: phoneIndex != null && phoneIndex < row.length
            ? row[phoneIndex].toString().trim()
            : null,
      ));
    }

    return students;
  }

  Future<List<StudentModel>> _parseExcelFile(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception("Excel file contains no sheets.");
    }

    // Use the first sheet
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw Exception("Excel sheet is empty.");
    }

    final rows = sheet.rows;

    // Get header row and find column indices
    final headerRow = rows.first;
    final header = headerRow
        .map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '')
        .toList();

    // Map common column variations to our expected fields
    int? nameIndex, rollIndex, photoIndex;
    int? programIndex, spCodeIndex, semesterIndex, statusIndex, durationIndex;
    int? emailIndex, dtuEmailIndex, phoneIndex;

    for (int i = 0; i < header.length; i++) {
      final col = header[i];

      // Map name columns
      if (col == 'name' ||
          col == 'fullname' ||
          col == 'student_name' ||
          col == 'full_name') {
        nameIndex = i;
      }
      // Map roll number columns
      else if (col == 'rollno' ||
          col == 'roll_no' ||
          col == 'roll' ||
          col == 'rollnumber' ||
          col == 'roll_number') {
        rollIndex = i;
      }
      // Map photo URL columns
      else if (col == 'photourl' ||
          col == 'photo_url' ||
          col == 'photo' ||
          col == 'image_url' ||
          col == 'picture') {
        photoIndex = i;
      }
      // Additional fields from Excel format
      else if (col == 'aprog' || col == 'program') {
        programIndex = i;
      } else if (col == 'sp_code' || col == 'spcode') {
        spCodeIndex = i;
      } else if (col == 'semester' || col == 'sem') {
        semesterIndex = i;
      } else if (col == 'status') {
        statusIndex = i;
      } else if (col == 'duration') {
        durationIndex = i;
      } else if (col == 'email') {
        emailIndex = i;
      } else if (col == 'dtu_email' || col == 'dtuemail') {
        dtuEmailIndex = i;
      } else if (col == 'phone' || col == 'mobile') {
        phoneIndex = i;
      }
    }

    // Check required columns (name and roll are mandatory)
    if (nameIndex == null || rollIndex == null) {
      final availableColumns = header.where((h) => h.isNotEmpty).join(', ');
      throw Exception(
          "Required columns not found. Looking for 'name/fullname' and 'rollno/roll_no' columns.\n"
          "Available columns: $availableColumns\n"
          "Supported name columns: name, fullname, student_name, full_name\n"
          "Supported roll columns: rollno, roll_no, roll, rollnumber, roll_number");
    }

    final List<StudentModel> students = [];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= nameIndex || row.length <= rollIndex) continue;

      final name = row[nameIndex]?.value?.toString().trim() ?? '';
      final rollno = row[rollIndex]?.value?.toString().trim() ?? '';
      final photoUrl = photoIndex != null && photoIndex < row.length
          ? (row[photoIndex]?.value?.toString().trim() ?? '')
          : '';

      if (name.isEmpty || rollno.isEmpty) continue;

      students.add(StudentModel(
        rno: rollno,
        name: name,
        photoUrl: photoUrl,
        program: programIndex != null && programIndex < row.length
            ? (row[programIndex]?.value?.toString().trim() ?? '')
            : null,
        spCode: spCodeIndex != null && spCodeIndex < row.length
            ? (row[spCodeIndex]?.value?.toString().trim() ?? '')
            : null,
        semester: semesterIndex != null && semesterIndex < row.length
            ? (row[semesterIndex]?.value?.toString().trim() ?? '')
            : null,
        status: statusIndex != null && statusIndex < row.length
            ? (row[statusIndex]?.value?.toString().trim() ?? '')
            : null,
        duration: durationIndex != null && durationIndex < row.length
            ? (row[durationIndex]?.value?.toString().trim() ?? '')
            : null,
        email: emailIndex != null && emailIndex < row.length
            ? (row[emailIndex]?.value?.toString().trim() ?? '')
            : null,
        dtuEmail: dtuEmailIndex != null && dtuEmailIndex < row.length
            ? (row[dtuEmailIndex]?.value?.toString().trim() ?? '')
            : null,
        phone: phoneIndex != null && phoneIndex < row.length
            ? (row[phoneIndex]?.value?.toString().trim() ?? '')
            : null,
      ));
    }

    return students;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text("Enroll New Class"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subjectCodeCtrl,
                decoration: const InputDecoration(
                    labelText: "Subject Code", border: OutlineInputBorder()),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectNameCtrl,
                decoration: const InputDecoration(
                    labelText: "Subject Name", border: OutlineInputBorder()),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sectionCtrl,
                decoration: const InputDecoration(
                    labelText: "Class Section/Slot",
                    border: OutlineInputBorder()),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Text('Course Structure:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('3L/1T/0P'),
                      value: '310',
                      groupValue: _ltpPattern,
                      activeColor: Colors.white,
                      fillColor: MaterialStateProperty.all(Colors.white),
                      onChanged: (value) {
                        setState(() {
                          _ltpPattern = value;
                          // Reset teacher type when LTP pattern changes
                          _teacherType = null;
                          _practicalGroupCtrl.clear();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('3L/0T/2P'),
                      value: '301',
                      groupValue: _ltpPattern,
                      activeColor: Colors.white,
                      fillColor: MaterialStateProperty.all(Colors.white),
                      onChanged: (value) {
                        setState(() {
                          _ltpPattern = value;
                          // Reset teacher type when LTP pattern changes
                          _teacherType = null;
                          _practicalGroupCtrl.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
              // Only show Teacher Type section if 3L/0T/2P is selected
              if (_ltpPattern == '301') ...[
                const SizedBox(height: 20),
                Text('Teacher Type:',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Lecture'),
                        value: 'Lecture',
                        groupValue: _teacherType,
                        activeColor: Colors.white,
                        fillColor: MaterialStateProperty.all(Colors.white),
                        onChanged: (value) {
                          setState(() {
                            _teacherType = value;
                            _practicalGroupCtrl.clear();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Practical'),
                        value: 'Practical',
                        groupValue: _teacherType,
                        activeColor: Colors.white,
                        fillColor: MaterialStateProperty.all(Colors.white),
                        onChanged: (value) {
                          setState(() {
                            _teacherType = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_teacherType == 'Practical') ...[
                  TextFormField(
                    controller: _practicalGroupCtrl,
                    decoration: const InputDecoration(
                        labelText: "Practical Group",
                        hintText: "e.g., G1, G2, etc.",
                        border: OutlineInputBorder()),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Required for Practical' : null,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              const Divider(),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(_fileName ?? "Select Student File (CSV/Excel)"),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _proceedToSchedule,
                icon: const Icon(Icons.arrow_forward),
                label: const Text("Next: Set Schedule"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
