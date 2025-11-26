import 'package:flutter/material.dart';
import 'package:samadhan_app/pages/add_student_page.dart';
import 'package:samadhan_app/pages/take_attendance_page.dart';
import 'package:samadhan_app/pages/view_attendance_page.dart'; // New import

class AttendanceOptionsPage extends StatelessWidget {
  const AttendanceOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Options'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Go back to Dashboard
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddStudentPage()),
                  );
                  print('Add Student button pressed');
                },
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add Student'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TakeAttendancePage()),
                  );
                  print('Take Attendance button pressed');
                },
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Take Attendance'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ViewAttendancePage(initialDate: DateTime.now())),
                  );
                  print('View Today\'s Attendance button pressed');
                },
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('View Today\'s Attendance'),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
