import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/providers/volunteer_provider.dart';
import 'package:intl/intl.dart';
import 'package:samadhan_app/pages/volunteer_daily_report_page.dart'; // Import to use StudentSelectionSheet

class EditVolunteerReportPage extends StatefulWidget {
  final VolunteerReport report;

  const EditVolunteerReportPage({super.key, required this.report});

  @override
  State<EditVolunteerReportPage> createState() => _EditVolunteerReportPageState();
}

class _EditVolunteerReportPageState extends State<EditVolunteerReportPage> {
  final _formKey = GlobalKey<FormState>();
  late String _volunteerName;
  TimeOfDay? _inTime;
  TimeOfDay? _outTime;
  String? _activityTaught;
  bool _testConducted = false;
  String? _testTopic;
  String? _marksGrade;
  List<int> _selectedStudents = []; // Changed to List<int>

  @override
  void initState() {
    super.initState();
    _volunteerName = widget.report.volunteerName;

    // Robust parsing for _inTime
    try {
      final parts = widget.report.inTime.split(':');
      _inTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      try {
        final dateTime = DateFormat('h:mm a').parse(widget.report.inTime);
        _inTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      } catch (e2) {
        _inTime = TimeOfDay.now(); // Fallback
      }
    }

    // Robust parsing for _outTime
    try {
      final parts = widget.report.outTime.split(':');
      _outTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      try {
        final dateTime = DateFormat('h:mm a').parse(widget.report.outTime);
        _outTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      } catch (e2) {
        _outTime = TimeOfDay.now(); // Fallback
      }
    }

    _activityTaught = widget.report.activityTaught;
    _testConducted = widget.report.testConducted;
    _testTopic = widget.report.testTopic;
    _marksGrade = widget.report.marksGrade;
    _selectedStudents = List<int>.from(widget.report.selectedStudents); // Ensure it's List<int>
  }
  
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != (isStartTime ? _inTime : _outTime)) {
      setState(() {
        if (isStartTime) {
          _inTime = picked;
        } else {
          _outTime = picked;
        }
      });
    }
  }

  void _showStudentSelectionSheet() async {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    // Filter students by the report's classBatch
    final studentsInReportClass = studentProvider.students
        .where((s) => s.classBatch == widget.report.classBatch)
        .toList();

    final List<int>? result = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return StudentSelectionSheet(
              scrollController: scrollController,
              allStudents: studentsInReportClass, // Pass only students from this report's class
              initiallySelectedStudents: _selectedStudents,
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedStudents = result;
      });
    }
  }

  Future<void> _updateReport() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final volunteerProvider = Provider.of<VolunteerProvider>(context, listen: false);

      final updatedReport = VolunteerReport(
        id: widget.report.id,
        volunteerName: _volunteerName,
        selectedStudents: _selectedStudents,
        classBatch: widget.report.classBatch, // Use the original classBatch
        inTime: _inTime!.format(context),
        outTime: _outTime!.format(context),
        activityTaught: _activityTaught!,
        testConducted: _testConducted,
        testTopic: _testTopic,
        marksGrade: _marksGrade,
      );

      await volunteerProvider.updateReport(updatedReport);
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Volunteer report updated successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Volunteer Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Go back to Dashboard
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: _volunteerName,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Volunteer Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showStudentSelectionSheet, // Call the new method
                child: Text('Selected Students (${_selectedStudents.length})'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.report.classBatch,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Class / Batch',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTime(context, true),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: TextEditingController(text: _inTime?.format(context) ?? ''),
                          decoration: InputDecoration(
                            labelText: 'In Time',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select in time';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectTime(context, false),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: TextEditingController(text: _outTime?.format(context) ?? ''),
                          decoration: InputDecoration(
                            labelText: 'Out Time',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select out time';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _activityTaught,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Activity Taught',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSaved: (value) => _activityTaught = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter activity taught';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Test Conducted'),
                value: _testConducted,
                onChanged: (bool value) {
                  setState(() {
                    _testConducted = value;
                  });
                },
              ),
              if (_testConducted) ...[
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _testTopic,
                  decoration: InputDecoration(
                    labelText: 'Test Topic',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSaved: (value) => _testTopic = value,
                  validator: (value) {
                    if (_testConducted && (value == null || value.isEmpty)) {
                      return 'Please enter test topic';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _marksGrade,
                  decoration: InputDecoration(
                    labelText: 'Marks/Grade',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSaved: (value) => _marksGrade = value,
                  validator: (value) {
                    if (_testConducted && (value == null || value.isEmpty)) {
                      return 'Please enter marks/grade';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement multi-select for students who attempted
                  },
                  child: const Text('Select Students Who Attempted'),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Update Report', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
