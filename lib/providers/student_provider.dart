import 'package:flutter/material.dart';
import 'package:samadhan_app/services/database_service.dart';
import 'package:sembast/sembast.dart';

class Student {
  final int id;
  final String name;
  final String rollNo;
  final String classBatch;
  bool isPresent; // Added for attendance page
  List<String> lessonsLearned; // List of activities/lessons taught to this student
  Map<String, String> testResults; // Map of testTopic -> marks/grade
  List<double>? embedding; // Face recognition embedding

  Student({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.classBatch,
    this.isPresent = false,
    List<String>? lessonsLearned,
    Map<String, String>? testResults,
    this.embedding,
  })  : this.lessonsLearned = lessonsLearned ?? [],
        this.testResults = testResults ?? {};

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'rollNo': rollNo,
      'classBatch': classBatch,
      'lessonsLearned': lessonsLearned,
      'testResults': testResults,
      'embedding': embedding,
    };
  }

  static Student fromMap(Map<String, dynamic> map, int id) {
    return Student(
      id: id,
      name: map['name'],
      rollNo: map['rollNo'],
      classBatch: map['classBatch'],
      lessonsLearned: map['lessonsLearned'] != null ? List<String>.from(map['lessonsLearned']) : [],
      testResults: map['testResults'] != null ? Map<String, String>.from(map['testResults']) : {},
      embedding: map['embedding'] != null ? List<double>.from(map['embedding']) : null,
    );
  }
}

class StudentProvider with ChangeNotifier {
  final _studentStore = intMapStoreFactory.store('students');
  final DatabaseService _dbService = DatabaseService();

  List<Student> _students = [];
  List<Student> get students => _students;

  Future<Student?> addStudent({
    required String name,
    required String rollNo,
    required String classBatch,
    List<double>? embedding,
  }) async {
    final db = await _dbService.database;

    // Check for existing student with same rollNo and classBatch
    final finder = Finder(filter: Filter.and([
      Filter.equals('rollNo', rollNo),
      Filter.equals('classBatch', classBatch),
    ]));
    final existingStudent = await _studentStore.findFirst(db, finder: finder);

    if (existingStudent != null) {
      return null; // Student with this roll number and class already exists
    }

    final studentData = {
      'name': name,
      'rollNo': rollNo,
      'classBatch': classBatch,
      'embedding': embedding
    };
    final newId = await _studentStore.add(db, studentData);
    final newStudent = Student.fromMap(studentData, newId);
    await fetchStudents(); // Refetch to keep the list in sync
    return newStudent;
  }

  Future<void> updateStudent(Student student) async {
    final db = await _dbService.database;
    await _studentStore.update(db, student.toMap(), finder: Finder(filter: Filter.byKey(student.id)));
    await fetchStudents();
  }

  Future<void> deleteStudent(int id) async {
    final db = await _dbService.database;
    await _studentStore.delete(db, finder: Finder(filter: Filter.byKey(id)));
    await fetchStudents();
  }

  Future<void> deleteMultipleStudents(List<int> ids) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await _studentStore.delete(txn, finder: Finder(filter: Filter.inList(Field.key, ids)));
    });
    await fetchStudents();
  }

  Future<void> fetchStudents() async {
    final db = await _dbService.database;
    final snapshots = await _studentStore.find(db);
    _students = snapshots.map((snapshot) {
      return Student.fromMap(snapshot.value, snapshot.key);
    }).toList();
    notifyListeners();
  }
}
