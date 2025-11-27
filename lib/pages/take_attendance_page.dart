import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/providers/attendance_provider.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/services/face_recognition_service.dart';
import 'package:samadhan_app/providers/notification_provider.dart';

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
    final XFile? imageFile = await _picker.pickImage(source: source, imageQuality: 80);

    if (imageFile != null) {
      setState(() {
        _pickedImage = File(imageFile.path);
        _isLoading = true;
        _errorMessage = null;
        _recognizedStudentNames.clear();
        _autoMarkedPresentCount = 0;
        // Reset all to absent
        for (var s in _attendanceList) {
          s.isPresent = false;
        }
      });

      try {
        final studentProvider = Provider.of<StudentProvider>(context, listen: false);
        final studentsWithEmbeddings = studentProvider.students.where((s) => s.embedding != null && s.embedding!.isNotEmpty).toList();

        final imageBytes = await _pickedImage!.readAsBytes();
        final image = img.decodeImage(imageBytes);

        if (image == null) {
          throw Exception("Could not decode image");
        }

        final detectedFaces = await _faceRecognitionService.detectFaces(image);

        if (detectedFaces.isEmpty) {
          setState(() {
            _errorMessage = 'No faces detected in the image.';
          });
        } else {
          List<String> recognizedThisImage = [];
          for (var face in detectedFaces) {
            final embedding = _faceRecognitionService.getEmbedding(image, face.boundingBox);
            if (embedding != null) {
              final bestMatch = _faceRecognitionService.findBestMatch(embedding, studentsWithEmbeddings, 0.8); // Using a threshold of 0.8
              if (bestMatch != null && !recognizedThisImage.contains(bestMatch.name)) {
                recognizedThisImage.add(bestMatch.name);
                final studentInList = _attendanceList.firstWhere((s) => s.id == bestMatch.id);
                studentInList.isPresent = true;
              }
            }
          }
          setState(() {
            _recognizedStudentNames = recognizedThisImage;
            _autoMarkedPresentCount = recognizedThisImage.length;
            if (recognizedThisImage.isEmpty) {
              _errorMessage = 'No known students were recognized.';
            }
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred during recognition: $e';
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

    final attendanceMap = {for (var student in _attendanceList) student.id: student.isPresent};
    
    await attendanceProvider.saveAttendance(attendanceMap);

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
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Gallery'),
                    ),
                  ],
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
