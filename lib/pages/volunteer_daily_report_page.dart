import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/providers/volunteer_provider.dart';
import 'package:samadhan_app/providers/user_provider.dart';
import 'package:samadhan_app/providers/notification_provider.dart'; // New import

class VolunteerDailyReportPage extends StatefulWidget {
  const VolunteerDailyReportPage({super.key});

  @override
  State<VolunteerDailyReportPage> createState() => _VolunteerDailyReportPageState();
}

class _VolunteerDailyReportPageState extends State<VolunteerDailyReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _volunteerNameController = TextEditingController(); // Use a controller
  String? _selectedClassBatch;
  late List<String> _classBatches;
  TimeOfDay? _inTime;
  TimeOfDay? _outTime;
  String? _activityTaught;
  bool _testConducted = false;
  String? _testTopic;
  String? _marksGrade;
  List<String> _selectedStudents = [];

  @override
  void initState() {
    super.initState();
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _volunteerNameController.text = userProvider.userSettings.name; // Set controller text
    _classBatches = ['All', ...studentProvider.students.map((s) => s.classBatch).toSet().toList()];
  }

  @override
  void dispose() {
    _volunteerNameController.dispose(); // Dispose the controller
    super.dispose();
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
    final allStudents = studentProvider.students;

    final List<String>? result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return _StudentSelectionSheet(
              scrollController: scrollController,
              allStudents: allStudents,
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

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final volunteerProvider = Provider.of<VolunteerProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

      final report = VolunteerReport(
        id: DateTime.now().millisecondsSinceEpoch,
        volunteerName: _volunteerNameController.text, // Use controller text
        selectedStudents: _selectedStudents,
        classBatch: _selectedClassBatch!,
        inTime: _inTime!.format(context),
        outTime: _outTime!.format(context),
        activityTaught: _activityTaught!,
        testConducted: _testConducted,
        testTopic: _testTopic,
        marksGrade: _marksGrade,
      );

      await volunteerProvider.addReport(report);

      notificationProvider.addNotification(
        title: 'Volunteer Report Submitted',
        message: 'Daily report for ${_volunteerNameController.text} in $_selectedClassBatch submitted. Activity: $_activityTaught.',
        type: 'success',
      );
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Volunteer report submitted successfully!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volunteer Daily Report'),
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
                controller: _volunteerNameController, // Use controller
                decoration: InputDecoration(
                  labelText: 'Volunteer Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a volunteer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showStudentSelectionSheet,
                child: Text('Select Students (${_selectedStudents.length})'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Class / Batch',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                value: _selectedClassBatch,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedClassBatch = newValue;
                  });
                },
                items: _classBatches.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a class/batch';
                  }
                  return null;
                },
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
                    print('Select Students who attempted button pressed');
                  },
                  child: const Text('Select Students Who Attempted'),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentSelectionSheet extends StatefulWidget {
  final ScrollController scrollController;
  final List<Student> allStudents;
  final List<String> initiallySelectedStudents;

  const _StudentSelectionSheet({
    required this.scrollController,
    required this.allStudents,
    required this.initiallySelectedStudents,
  });

  @override
  State<_StudentSelectionSheet> createState() => _StudentSelectionSheetState();
}

class _StudentSelectionSheetState extends State<_StudentSelectionSheet> {
  late final Map<String, List<Student>> _groupedStudents;
  late final Set<String> _selectedStudents;
  String? _expandedClass;

  @override
  void initState() {
    super.initState();
    _selectedStudents = Set<String>.from(widget.initiallySelectedStudents);
    _groupedStudents = {};
    for (var student in widget.allStudents) {
      (_groupedStudents[student.classBatch] ??= []).add(student);
    }
  }

  void _onSelectAll(String classBatch, bool? isSelected) {
    final studentsInClass = _groupedStudents[classBatch]!.map((s) => s.name).toList();
    setState(() {
      // When selecting all for a new class, clear all previous selections.
      _selectedStudents.clear();
      if (isSelected == true) {
        _selectedStudents.addAll(studentsInClass);
      }
    });
  }

  void _onStudentSelected(String studentName, bool? isSelected) {
    // Find the class of the student being selected.
    final studentClass = _groupedStudents.entries
        .firstWhere((entry) => entry.value.any((s) => s.name == studentName))
        .key;
        
    setState(() {
      // Check if there are existing selections from a different class.
      if (_selectedStudents.isNotEmpty) {
        final firstSelectedStudentName = _selectedStudents.first;
        final firstSelectedStudentClass = _groupedStudents.entries
            .firstWhere((entry) => entry.value.any((s) => s.name == firstSelectedStudentName))
            .key;
        
        if (studentClass != firstSelectedStudentClass) {
          // If the class is different, clear the old selections.
          _selectedStudents.clear();
        }
      }

      // Add or remove the current student.
      if (isSelected == true) {
        _selectedStudents.add(studentName);
      } else {
        _selectedStudents.remove(studentName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final classBatches = _groupedStudents.keys.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Select Students', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            children: [
              ExpansionPanelList(
                expansionCallback: (int panelIndex, bool isExpanded) {
                  setState(() {
                    _expandedClass = isExpanded ? classBatches[panelIndex] : null;
                  });
                },
                children: classBatches.map<ExpansionPanel>((String classBatch) {
                  final studentsInClass = _groupedStudents[classBatch]!;
                  final areAllSelected = studentsInClass.every((s) => _selectedStudents.contains(s.name));
                  
                  return ExpansionPanel(
                    isExpanded: _expandedClass == classBatch,
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text('Class $classBatch'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Select All'),
                            Checkbox(
                              value: areAllSelected,
                              onChanged: (bool? value) {
                                _onSelectAll(classBatch, value);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    body: Column(
                      children: studentsInClass.map((Student student) {
                        return CheckboxListTile(
                          title: Text(student.name),
                          value: _selectedStudents.contains(student.name),
                          onChanged: (bool? value) {
                            _onStudentSelected(student.name, value);
                          },
                          activeColor: Colors.green,
                          checkColor: Colors.white,
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(_selectedStudents.toList());
            },
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}