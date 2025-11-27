import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for FilteringTextInputFormatter
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/services/face_recognition_service.dart';
import 'package:samadhan_app/providers/notification_provider.dart';
import 'package:samadhan_app/providers/offline_sync_provider.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollNoController = TextEditingController();
  String? _selectedClass;
  final List<String> _classes = List.generate(12, (index) => (index + 1).toString());

  final List<File?> _photoFiles = List.filled(5, null);
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() {
        _photoFiles[index] = File(image.path);
      });
    }
  }

  Future<void> _addStudentAndTrain() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      final studentProvider = Provider.of<StudentProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      final faceService = FaceRecognitionService();
      
      List<double>? embedding;
      final photo = _photoFiles.firstWhere((f) => f != null, orElse: () => null);

      if (photo != null) {
        try {
          final imageBytes = await photo.readAsBytes();
          final image = img.decodeImage(imageBytes);

          if (image != null) {
            final faces = await faceService.detectFaces(image);
            if (faces.length != 1) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please use a clear photo with exactly one face. ${faces.length} faces detected.'), backgroundColor: Colors.red));
              setState(() => _isLoading = false);
              return;
            } else {
              embedding = faceService.getEmbedding(image, faces.first.boundingBox);
            }
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing image: $e'), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
          return;
        }
      }

      try {
        final newStudent = await studentProvider.addStudent(
          name: _nameController.text,
          rollNo: _rollNoController.text,
          classBatch: _selectedClass!,
          embedding: embedding,
        );

        if (newStudent == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This roll number is already assigned in this class.'), backgroundColor: Colors.red));
          return;
        }

        notificationProvider.addNotification(
          title: 'Student Added',
          message: 'Student ${newStudent.name} has been added successfully.',
          type: 'success',
        );

        if (mounted) Navigator.pop(context);

      } catch (e) {
        notificationProvider.addNotification(
          title: 'Failed to Add Student',
          message: 'An error occurred while adding student: $e',
          type: 'alert',
        );
      } finally {
        if(mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Student'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), // Allow letters and spaces
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter student name';
                  }

                  // Only letters and spaces allowed
                  final nameRegex = RegExp(r'^[a-zA-Z ]+$');
                  if (!nameRegex.hasMatch(value)) {
                    return 'Only letters and spaces allowed';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Class',
                ),
                value: _selectedClass,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedClass = newValue;
                  });
                  // Trigger validation for other fields when class changes
                  _formKey.currentState?.validate();
                },
                items: _classes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a class';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rollNoController,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Allow only digits
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter roll number';
                  }

                  if (value.contains(' ')) {
                    return 'Roll number cannot contain spaces';
                  }

                  final digitRegex = RegExp(r'^[0-9]+$');
                  if (!digitRegex.hasMatch(value)) {
                    return 'Roll number must contain digits only';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text('Upload Photos for Training (5 slots)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _pickImage(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: _photoFiles[index] == null
                          ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_photoFiles[index]!, fit: BoxFit.cover),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _addStudentAndTrain,
                  child: const Text('ADD STUDENT', style: TextStyle(fontSize: 18)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}