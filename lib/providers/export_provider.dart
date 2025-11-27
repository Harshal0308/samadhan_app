import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/providers/volunteer_provider.dart';
import 'package:samadhan_app/providers/attendance_provider.dart'; // Import AttendanceProvider
import 'package:printing/printing.dart';

class ExportProvider {
  final StudentProvider _studentProvider;

  ExportProvider(this._studentProvider);

  // Helper to get application documents directory
  Future<String> _getLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<String> exportAttendanceToExcel(List<AttendanceRecord> attendanceRecords, {DateTime? startDate, DateTime? endDate}) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    // Prepare student data for lookup
    final Map<int, Student> studentsMap = {for (var s in _studentProvider.students) s.id: s};

    // Determine all unique dates for columns
    final List<DateTime> uniqueDates = attendanceRecords.map((record) => DateTime(record.date.year, record.date.month, record.date.day)).toSet().toList();
    uniqueDates.sort((a, b) => a.compareTo(b));

    // Create header row: Student Info + Dates
    List<CellValue> header = [
      TextCellValue('Student ID'),
      TextCellValue('Student Name'),
      TextCellValue('Roll No'),
      TextCellValue('Class/Batch'),
    ];
    for (var date in uniqueDates) {
      header.add(TextCellValue('${date.day}/${date.month}'));
    }
    sheet.insertRowIterables(header, 0);

    // Create data rows for each student
    int rowIndex = 1;
    for (var student in _studentProvider.students) {
      List<CellValue> row = [
        TextCellValue(student.id.toString()),
        TextCellValue(student.name),
        TextCellValue(student.rollNo),
        TextCellValue(student.classBatch),
      ];

      for (var date in uniqueDates) {
        bool presentForDate = false;
        // Find attendance record for this student on this date
        for (var record in attendanceRecords) {
          if (record.date.year == date.year &&
              record.date.month == date.month &&
              record.date.day == date.day &&
              record.attendance.containsKey(student.id)) {
            if (record.attendance[student.id] == true) {
              presentForDate = true;
              break;
            }
          }
        }
        row.add(TextCellValue(presentForDate ? 'P' : 'A'));
      }
      sheet.insertRowIterables(row, rowIndex++);
    }

    // Generate filename based on date range
    String filename = 'Attendance';
    if (startDate != null && endDate != null) {
      final monthStart = _getMonthName(startDate.month);
      final dayStart = startDate.day;
      final yearStart = startDate.year;
      final monthEnd = _getMonthName(endDate.month);
      final dayEnd = endDate.day;
      final yearEnd = endDate.year;
      
      if (startDate.year == endDate.year && startDate.month == endDate.month && startDate.day == endDate.day) {
        // Same day
        filename = 'Attendance_${dayStart}_${monthStart}_$yearStart';
      } else {
        // Date range
        filename = 'Attendance_${dayStart}_${monthStart}_${yearStart}_to_${dayEnd}_${monthEnd}_${yearEnd}';
      }
    } else {
      // Fallback if dates not provided
      final now = DateTime.now();
      filename = 'Attendance_${now.day}_${_getMonthName(now.month)}_${now.year}';
    }

    final path = '${await _getLocalPath()}/${filename}.xlsx';
    final fileBytes = excel.save();
    if (fileBytes != null) {
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      return path;
    }
    throw Exception('Failed to save Excel file.');
  }

  Future<String> exportVolunteerReportToPdf(List<VolunteerReport> reports, {DateTime? startDate, DateTime? endDate}) async {
    final pdf = pw.Document();
    final Map<int, Student> studentsMap = {for (var s in _studentProvider.students) s.id: s};

    for (var report in reports) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Volunteer Daily Report',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Text('Date: ${DateTime.fromMillisecondsSinceEpoch(report.id).toIso8601String().substring(0, 10)}'),
                pw.Text('Volunteer: ${report.volunteerName}'),
                pw.Text('Class/Batch: ${report.classBatch}'),
                pw.Text('In Time: ${report.inTime}, Out Time: ${report.outTime}'),
                pw.Text('Activity Taught: ${report.activityTaught}'),
                pw.SizedBox(height: 10),
                pw.Header(level: 1, text: 'Selected Students'),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: report.selectedStudents.map((studentId) {
                    final studentName = studentsMap[studentId]?.name ?? 'Unknown Student ($studentId)';
                    return pw.Text('• $studentName');
                  }).toList(),
                ),
                if (report.testConducted) ...[                  
                  pw.SizedBox(height: 10),
                  pw.Header(level: 1, text: 'Test Details'),
                  pw.Text('Test Topic: ${report.testTopic ?? 'N/A'}'),
                  pw.SizedBox(height: 10),
                  pw.Header(level: 2, text: 'Students Who Took Test'),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: report.testStudents.map((studentId) {
                      final studentName = studentsMap[studentId]?.name ?? 'Unknown Student ($studentId)';
                      final marks = report.testMarks[studentId] ?? 'N/A';
                      return pw.Text('• $studentName - Marks: $marks');
                    }).toList(),
                  ),
                ]
              ],
            );
          },
        ),
      );
    }

    // Generate filename based on date range
    String filename = 'VolunteerReport';
    if (startDate != null && endDate != null) {
      final monthStart = _getMonthName(startDate.month);
      final dayStart = startDate.day;
      final yearStart = startDate.year;
      final monthEnd = _getMonthName(endDate.month);
      final dayEnd = endDate.day;
      final yearEnd = endDate.year;
      
      if (startDate.year == endDate.year && startDate.month == endDate.month && startDate.day == endDate.day) {
        // Same day
        filename = 'VolunteerReport_${dayStart}_${monthStart}_$yearStart';
      } else {
        // Date range
        filename = 'VolunteerReport_${dayStart}_${monthStart}_${yearStart}_to_${dayEnd}_${monthEnd}_${yearEnd}';
      }
    } else {
      // Fallback if dates not provided
      final now = DateTime.now();
      filename = 'VolunteerReport_${now.day}_${_getMonthName(now.month)}_${now.year}';
    }

    final path = '${await _getLocalPath()}/${filename}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return path;
  }
  
  
  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<List<File>> getExportedFiles() async {
    final directory = Directory(await _getLocalPath());
    if (!await directory.exists()) {
      return [];
    }
    final files = directory.listSync().whereType<File>().where((file) {
      final fileName = file.path.split(Platform.pathSeparator).last;
      return fileName.startsWith('Attendance') || fileName.startsWith('VolunteerReport');
    }).toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }
}
