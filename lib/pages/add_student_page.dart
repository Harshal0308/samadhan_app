import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/services/face_recognition_service.dart';
import 'package:samadhan_app/providers/notification_provider.dart';
import 'package:samadhan_app/pages/image_cropper_page.dart';
import 'package:image/image.dart' as img;


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
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && mounted) {
      // Navigate to the new full-screen cropper page
      final img.Image? croppedImage = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageCropperPage(
            imageFile: File(pickedFile.path),
          ),
        ),
      );

      if (croppedImage != null) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final croppedFile = await File(path).writeAsBytes(img.encodeJpg(croppedImage));

        setState(() {
          _photoFiles[index] = croppedFile;
        });
      }
    }
  }

  Future<void> _addStudentAndTrain() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      final studentProvider = Provider.of<StudentProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      final faceService = FaceRecognitionService();
      
      List<double>? finalEmbedding;
      List<List<double>> collectedEmbeddings = [];
      String photoProcessingErrors = '';
      int processedPhotosCount = 0;

      for (int i = 0; i < _photoFiles.length; i++) {
        final croppedPhotoFile = _photoFiles[i];
        if (croppedPhotoFile != null) {
          processedPhotosCount++;
          try {
            final currentEmbedding = await faceService.getEmbeddingForCroppedImage(croppedPhotoFile);

            if (currentEmbedding != null) {
              collectedEmbeddings.add(currentEmbedding);
            } else {
              photoProcessingErrors += 'Photo ${i + 1}: Failed to generate embedding from cropped image.\n';
            }
          } catch (e) {
            photoProcessingErrors += 'Photo ${i + 1}: Error processing cropped image ($e).\n';
          }
        }
      }

      if (processedPhotosCount == 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload and crop at least one photo.'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }

      if (collectedEmbeddings.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate any valid face embeddings. Details:\n$photoProcessingErrors'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }

      finalEmbedding = faceService.averageEmbeddings(collectedEmbeddings);
      if (finalEmbedding == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to average face embeddings.'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
        return;
      }

      if (photoProcessingErrors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Some cropped photos had issues. Final embedding generated from valid photos. Details:\n$photoProcessingErrors'), backgroundColor: Colors.orange));
      }

      try {
        final newStudent = await studentProvider.addStudent(
          name: _nameController.text,
          rollNo: _rollNoController.text,
          classBatch: _selectedClass!,
          embedding: finalEmbedding,
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
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter student name';
                  }
                  if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) {
                    return 'Only letters and spaces are allowed';
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
                },
                items: _classes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                validator: (value) => value == null ? 'Please select a class' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rollNoController,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter roll number';
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
