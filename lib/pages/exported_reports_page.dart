import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/providers/attendance_provider.dart';
import 'package:samadhan_app/providers/export_provider.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/providers/volunteer_provider.dart';
import 'package:samadhan_app/providers/notification_provider.dart';

class ExportedReportsPage extends StatefulWidget {
  const ExportedReportsPage({super.key});

  @override
  State<ExportedReportsPage> createState() => _ExportedReportsPageState();
}

class _ExportedReportsPageState extends State<ExportedReportsPage> {
  late Future<List<File>> _exportedFilesFuture;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    // Fetch volunteer and attendance reports first, then load exported files
    final volunteerProvider = Provider.of<VolunteerProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    
    Future.wait([
      volunteerProvider.fetchReports(),
      attendanceProvider.fetchAttendanceRecords(),
    ]).then((_) {
      _loadExportedFiles();
    });
    
    // Default to last 30 days
    _selectedStartDate = DateTime.now().subtract(const Duration(days: 30));
    _selectedEndDate = DateTime.now();
  }

  void _loadExportedFiles() {
    final exportProvider = Provider.of<ExportProvider>(context, listen: false);
    setState(() {
      _exportedFilesFuture = exportProvider.getExportedFiles();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _selectedStartDate : _selectedEndDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
          if (_selectedEndDate != null && _selectedStartDate!.isAfter(_selectedEndDate!)) {
            _selectedEndDate = picked; // Adjust end date if it's before start date
          }
        } else {
          _selectedEndDate = picked;
          if (_selectedStartDate != null && _selectedEndDate!.isBefore(_selectedStartDate!)) {
            _selectedStartDate = picked; // Adjust start date if it's after end date
          }
        }
      });
    }
  }

  Future<void> _generateAttendanceReport() async {
    if (_selectedStartDate == null || _selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range for the attendance report.')),
      );
      return;
    }

    final exportProvider = Provider.of<ExportProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    // Fetch attendance records for the selected date range
    final attendanceRecords = await attendanceProvider.fetchAttendanceRecordsByDateRange(_selectedStartDate!, _selectedEndDate!);

    if (attendanceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records found for the selected date range.')),
      );
      notificationProvider.addNotification(
        title: 'Attendance Export Failed',
        message: 'No attendance records found for the selected date range (${_selectedStartDate!.toLocal().toString().split(' ')[0]} to ${_selectedEndDate!.toLocal().toString().split(' ')[0]}).',
        type: 'warning',
      );
      return;
    }

    try {
      final path = await exportProvider.exportAttendanceToExcel(
        attendanceRecords,
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance report saved to $path')),
      );
      notificationProvider.addNotification(
        title: 'Attendance Report Exported',
        message: 'Attendance report for ${_selectedStartDate!.toLocal().toString().split(' ')[0]} to ${_selectedEndDate!.toLocal().toString().split(' ')[0]} saved successfully.',
        type: 'success',
      );
      _loadExportedFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate attendance report: $e')),
      );
      notificationProvider.addNotification(
        title: 'Attendance Export Failed',
        message: 'Failed to generate attendance report: $e',
        type: 'alert',
      );
    }
  }

  Future<void> _generateVolunteerReport(List<VolunteerReport> reports) async {
    final exportProvider = Provider.of<ExportProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    print('DEBUG: _generateVolunteerReport called with ${reports.length} reports');
    
    try {
      if (reports.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No reports to export.')),
        );
        return;
      }
      
      final path = await exportProvider.exportVolunteerReportToPdf(
        reports,
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
      );
      print('DEBUG: PDF generated successfully at $path');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Volunteer report saved to $path')),
      );
      notificationProvider.addNotification(
        title: 'Volunteer Report Exported',
        message: 'Volunteer report for selected range exported successfully.',
        type: 'success',
      );
      _loadExportedFiles();
    } catch (e, stackTrace) {
      print('DEBUG: Error generating volunteer report: $e');
      print('DEBUG: Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate volunteer report: $e')),
      );
      notificationProvider.addNotification(
        title: 'Volunteer Report Export Failed',
        message: 'Failed to generate volunteer report: $e',
        type: 'alert',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exported Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Date Range Selectors for Attendance
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectDate(context, true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_selectedStartDate == null
                            ? 'Select Start Date'
                            : 'Start: ${_selectedStartDate!.toLocal().toString().split(' ')[0]}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selectDate(context, false),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_selectedEndDate == null
                            ? 'Select End Date'
                            : 'End: ${_selectedEndDate!.toLocal().toString().split(' ')[0]}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _generateAttendanceReport,
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Generate New Attendance Excel'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 10),
                Consumer<VolunteerProvider>(
                  builder: (context, volunteerProvider, child) {
                    return ElevatedButton.icon(
                      onPressed: () {
                        if (_selectedStartDate == null || _selectedEndDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a date range for the volunteer report.')),
                          );
                          return;
                        }
                        final reports = volunteerProvider.reports.where((report) {
                          final reportDate = DateTime.fromMillisecondsSinceEpoch(report.id);
                          final startDate = DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day);
                          final endDate = DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day + 1);
                          return !reportDate.isBefore(startDate) && reportDate.isBefore(endDate);
                        }).toList();

                        print('DEBUG: Total reports available: ${volunteerProvider.reports.length}');
                        print('DEBUG: Reports in selected date range: ${reports.length}');
                        for (var r in reports) {
                          print('DEBUG: Report date: ${DateTime.fromMillisecondsSinceEpoch(r.id)}');
                        }

                        if (reports.isNotEmpty) {
                          _generateVolunteerReport(reports);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No volunteer reports available to export for the selected date range.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Generate Volunteer Report PDF'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<File>>(
              future: _exportedFilesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No exported reports found.'));
                }

                final files = snapshot.data!;
                final attendanceFiles = files.where((f) => f.path.contains('Attendance')).toList();
                final volunteerFiles = files.where((f) => f.path.contains('VolunteerReport')).toList();

                return ListView(
                  children: [
                    if (attendanceFiles.isNotEmpty)
                      _buildReportSection(context, 'Attendance Excel Files', attendanceFiles, Icons.description, Colors.green),
                    if (volunteerFiles.isNotEmpty)
                      _buildReportSection(context, 'Volunteer Daily Reports (PDF)', volunteerFiles, Icons.picture_as_pdf, Colors.red),
                    if (attendanceFiles.isEmpty && volunteerFiles.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No exported reports found.'),
                      )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(BuildContext context, String title, List<File> files, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final fileName = file.path.split(Platform.pathSeparator).last;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(icon, color: color),
                title: Text(fileName),
                subtitle: Text('Modified: ${file.lastModifiedSync().toString().substring(0, 16)}'),
                onTap: () async {
                  final result = await OpenFile.open(file.path);
                  if (result.type != ResultType.done) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open file: ${result.message}')),
                    );
                  }
                },
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}