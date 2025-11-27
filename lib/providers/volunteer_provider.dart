import 'package:flutter/material.dart';
import 'package:samadhan_app/services/database_service.dart';
import 'package:sembast/sembast.dart';

class VolunteerReport {
  final int id;
  final String volunteerName;
  final List<int> selectedStudents; // Changed to List<int>
  final String classBatch;
  final String inTime;
  final String outTime;
  final String activityTaught;
  final bool testConducted;
  final String? testTopic;
  final String? marksGrade;
  final List<int> testStudents; // Students who took the test
  final Map<int, String> testMarks; // Map of studentId -> marks/grade

  VolunteerReport({
    required this.id,
    required this.volunteerName,
    required this.selectedStudents,
    required this.classBatch,
    required this.inTime,
    required this.outTime,
    required this.activityTaught,
    required this.testConducted,
    this.testTopic,
    this.marksGrade,
    this.testStudents = const [],
    this.testMarks = const {},
  });

  factory VolunteerReport.fromMap(Map<String, dynamic> map, int id) {
    List<int> studentIds = [];
    if (map['selectedStudents'] != null) {
      try {
        studentIds = (map['selectedStudents'] as List).map((e) => int.parse(e.toString())).toList();
      } catch (e) {
        // This can happen if old data contains student names instead of IDs.
        // We'll leave the list empty to avoid a crash.
        studentIds = [];
        print("Could not parse selected students: $e");
      }
    }
    List<int> testStudentIds = [];
    if (map['testStudents'] != null) {
      try {
        testStudentIds = (map['testStudents'] as List).map((e) => int.parse(e.toString())).toList();
      } catch (e) {
        testStudentIds = [];
      }
    }
    Map<int, String> marksMap = {};
    if (map['testMarks'] != null) {
      (map['testMarks'] as Map).forEach((key, value) {
        marksMap[int.parse(key.toString())] = value.toString();
      });
    }
    return VolunteerReport(
      id: id,
      volunteerName: map['volunteerName'],
      selectedStudents: studentIds,
      classBatch: map['classBatch'],
      inTime: map['inTime'],
      outTime: map['outTime'],
      activityTaught: map['activityTaught'],
      testConducted: map['testConducted'],
      testTopic: map['testTopic'],
      marksGrade: map['marksGrade'],
      testStudents: testStudentIds,
      testMarks: marksMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'volunteerName': volunteerName,
      'selectedStudents': selectedStudents,
      'classBatch': classBatch,
      'inTime': inTime,
      'outTime': outTime,
      'activityTaught': activityTaught,
      'testConducted': testConducted,
      'testTopic': testTopic,
      'marksGrade': marksGrade,
      'testStudents': testStudents,
      'testMarks': testMarks.map((key, value) => MapEntry(key.toString(), value)),
    };
  }
}

class VolunteerProvider with ChangeNotifier {
  final _reportStore = intMapStoreFactory.store('volunteer_reports');
  final DatabaseService _dbService = DatabaseService();

  List<VolunteerReport> _reports = [];
  List<VolunteerReport> get reports => _reports;

  Future<void> addReport(VolunteerReport report) async {
    final db = await _dbService.database;
    // Use the provided report.id (which is a timestamp) as the record key
    // so that stored reports keep their original DateTime identity.
    await _reportStore.record(report.id).put(db, report.toMap());
    print('DEBUG: Report saved with ID: ${report.id}, Volunteer: ${report.volunteerName}');
    await fetchReports(); // refetch to update the list
  }
  
  Future<void> updateReport(VolunteerReport report) async {
    final db = await _dbService.database;
    await _reportStore.update(db, report.toMap(), finder: Finder(filter: Filter.byKey(report.id)));
    await fetchReports();
  }
  
  Future<void> deleteMultipleReports(List<int> ids) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await _reportStore.delete(txn, finder: Finder(filter: Filter.byKey(ids)));
    });
    await fetchReports();
  }

  Future<void> fetchReports() async {
    final db = await _dbService.database;
    final snapshots = await _reportStore.find(db);
    _reports = snapshots.map((snapshot) {
      return VolunteerReport.fromMap(snapshot.value, snapshot.key);
    }).toList();
    // Sort by date descending (newest first)
    _reports.sort((a, b) => b.id.compareTo(a.id));
    print('DEBUG: fetchReports - Found ${_reports.length} reports');
    for (var r in _reports) {
      print('DEBUG: Report - ID: ${r.id}, Date: ${DateTime.fromMillisecondsSinceEpoch(r.id)}, Volunteer: ${r.volunteerName}');
    }
    notifyListeners();
  }
}
