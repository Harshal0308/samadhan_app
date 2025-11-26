import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/providers/attendance_provider.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/services/face_recognition_service.dart';
import 'package:samadhan_app/providers/notification_provider.dart';
import 'package:samadhan_app/providers/offline_sync_provider.dart'; // New import

class TakeAttendancePage extends StatefulWidget {
  const TakeAttendancePage({super.key});

  @override
  State<TakeAttendancePage> createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends State<TakeAttendancePage> {
  final ImagePicker _picker = ImagePicker();
  final FaceRecognitionService _faceRecognitionService = FaceRecognitionService();
  File? _pickedImage;
  bool _isLoading = false;
  String? _errorMessage;

  List<Student> _attendanceList = [];
  int _autoMarkedPresentCount = 0;
  List<String> _recognizedStudentNames = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    setState(() {
      _attendanceList = studentProvider.students.map((s) => Student(id: s.id, name: s.name, rollNo: s.rollNo, classBatch: s.classBatch, isPresent: false)).toList();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 50);

    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
        _isLoading = true;
        _errorMessage = null;
        _autoMarkedPresentCount = 0;
        _recognizedStudentNames.clear();
        for (var s in _attendanceList) {
          s.isPresent = false;
        }
      });

      try {
        final response = await _faceRecognitionService.recognizeFaces([_pickedImage!]);

        if (response.containsKey('error')) {
          setState(() {
            _errorMessage = response['error'];
          });
        } else if (response.containsKey('results') && response['results'] is List && response['results'].isNotEmpty) {
          final List<dynamic> recognizedNamesData = response['results'][0]['recognized_names'];
          final List<String> detectedNames = recognizedNamesData.map((name) => name.toString()).toList();

          setState(() {
            _recognizedStudentNames = detectedNames;
            _autoMarkedPresentCount = detectedNames.length;
            for (var student in _attendanceList) {
              if (detectedNames.contains(student.name)) {
                student.isPresent = true;
              }
            }
          });
        } else {
          _errorMessage = 'No faces were recognized.';
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAttendance() async {
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final offlineSyncProvider = Provider.of<OfflineSyncProvider>(context, listen: false);

    final attendanceMap = {for (var student in _attendanceList) student.id: student.isPresent};
    
    await attendanceProvider.saveAttendance(attendanceMap);
    offlineSyncProvider.addPendingChange();

    final presentCount = _attendanceList.where((s) => s.isPresent).length;
    final absentCount = _attendanceList.where((s) => !s.isPresent).length;
    final totalStudents = _attendanceList.length;

    notificationProvider.addNotification(
      title: 'Attendance Saved',
      message: 'Attendance for ${DateTime.now().toLocal().toString().split(' ')[0]} saved: $presentCount present, $absentCount absent out of $totalStudents students.',
      type: 'success',
    );

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildRecognitionSection(),
              _buildStudentList(),
              _buildBottomActions(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecognitionSection() {
    return Consumer<OfflineSyncProvider>(
      builder: (context, syncProvider, child) {
        return Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_pickedImage != null)
                      Image.file(_pickedImage!, height: 120, fit: BoxFit.cover),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: syncProvider.isOnline ? () => _pickImage(ImageSource.camera) : null,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          onPressed: syncProvider.isOnline ? () => _pickImage(ImageSource.gallery) : null,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('From Gallery'),
                        ),
                      ],
                    ),
                    if (!syncProvider.isOnline)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('Face recognition is available only when online.', style: TextStyle(color: Colors.grey)),
                      ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                      ),
                    if (_recognizedStudentNames.isNotEmpty)
                       Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '$_autoMarkedPresentCount Students Auto-Marked Present:',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Wrap(
                      spacing: 8.0,
                      children: _recognizedStudentNames.map((name) => Chip(label: Text(name))).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentList() {
    if (_attendanceList.isEmpty) {
      return const Expanded(flex: 3, child: Center(child: Text('No students found. Please add students first.')));
    }
    return Expanded(
      flex: 3,
      child: ListView.builder(
        itemCount: _attendanceList.length,
        itemBuilder: (context, index) {
          final student = _attendanceList[index];
          return ListTile(
            title: Text(student.name),
            subtitle: Text('Roll No: ${student.rollNo}'),
            trailing: Switch(
              value: student.isPresent,
              onChanged: (value) => setState(() => student.isPresent = value),
            ),
            onTap: () => setState(() => student.isPresent = !student.isPresent),
          );
        },
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveAttendance,
                  child: const Text('Save Attendance'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { /* TODO: Export Excel */ },
                  child: const Text('Export Excel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
