import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';

class PdfService {
  static Future<Uint8List> generateAttendanceReport({
    required ClassModel classModel,
    required AttendanceModel attendanceRecord,
  }) async {
    final pdf = pw.Document();

    // Load custom font (optional)
    pw.Font? customFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      customFont = pw.Font.ttf(fontData);
    } catch (e) {
      // Use default font if custom font is not available
      customFont = null;
    }

    // Calculate statistics
    final totalStudents = classModel.students.length;
    final presentCount = attendanceRecord.studentStatuses.values
        .where((status) => status.toLowerCase() == 'present')
        .length;
    final absentCount = totalStudents - presentCount;
    final attendancePercent = totalStudents > 0
        ? (presentCount / totalStudents * 100).toStringAsFixed(1)
        : "0";

    // Format date
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy')
        .format(DateTime.parse(attendanceRecord.date));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(width: 2, color: PdfColors.blue),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Attendance Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                      font: customFont,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Class: ${classModel.name}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: customFont,
                    ),
                  ),
                  pw.Text(
                    'Date: $formattedDate',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                      font: customFont,
                    ),
                  ),
                  pw.Text(
                    'Generated on: ${DateFormat('MMM d, yyyy at h:mm a').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                      font: customFont,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Statistics Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Attendance Summary',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      font: customFont,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn('Total Students',
                          totalStudents.toString(), PdfColors.blue, customFont),
                      _buildStatColumn('Present', presentCount.toString(),
                          PdfColors.green, customFont),
                      _buildStatColumn('Absent', absentCount.toString(),
                          PdfColors.red, customFont),
                      _buildStatColumn('Attendance %', '$attendancePercent%',
                          PdfColors.orange, customFont),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Student List Table
            pw.Text(
              'Detailed Attendance',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                font: customFont,
              ),
            ),
            pw.SizedBox(height: 12),

            // Table Header
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FixedColumnWidth(60), // S.No
                1: const pw.FixedColumnWidth(120), // Roll No (increased width)
                2: const pw.FlexColumnWidth(2), // Name
                3: const pw.FixedColumnWidth(80), // Status
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _buildTableCell('S.No', isHeader: true, font: customFont),
                    _buildTableCell('Roll No',
                        isHeader: true, font: customFont),
                    _buildTableCell('Student Name',
                        isHeader: true, font: customFont),
                    _buildTableCell('Status', isHeader: true, font: customFont),
                  ],
                ),
                // Student rows
                ...classModel.students.asMap().entries.map((entry) {
                  final index = entry.key;
                  final student = entry.value;
                  final status =
                      attendanceRecord.studentStatuses[student.rno] ?? 'absent';
                  final isPresent = status.toLowerCase() == 'present';

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color:
                          index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      _buildTableCell('${index + 1}', font: customFont),
                      _buildTableCell(student.rno, font: customFont),
                      _buildTableCell(student.name, font: customFont),
                      _buildTableCell(
                        isPresent ? 'Present' : 'Absent',
                        font: customFont,
                        textColor:
                            isPresent ? PdfColors.green700 : PdfColors.red700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
                font: customFont,
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildStatColumn(
      String label, String value, PdfColor color, pw.Font? font) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: color,
            font: font,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
            font: font,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.Font? font,
    PdfColor? textColor,
    pw.FontWeight? fontWeight,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: fontWeight ??
              (isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
          color: textColor ?? (isHeader ? PdfColors.blue900 : PdfColors.black),
          font: font,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static Future<void> shareAttendanceReport({
    required ClassModel classModel,
    required AttendanceModel attendanceRecord,
  }) async {
    try {
      final pdfData = await generateAttendanceReport(
        classModel: classModel,
        attendanceRecord: attendanceRecord,
      );

      final fileName =
          'attendance_${classModel.name.replaceAll(' ', '_')}_${attendanceRecord.date}.pdf';

      await Printing.sharePdf(
        bytes: pdfData,
        filename: fileName,
      );
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  static Future<void> printAttendanceReport({
    required ClassModel classModel,
    required AttendanceModel attendanceRecord,
  }) async {
    try {
      final pdfData = await generateAttendanceReport(
        classModel: classModel,
        attendanceRecord: attendanceRecord,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
      );
    } catch (e) {
      throw Exception('Failed to print PDF: $e');
    }
  }
}
