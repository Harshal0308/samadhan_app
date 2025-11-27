import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/pages/login_page.dart';
import 'package:samadhan_app/pages/main_dashboard_page.dart';
import 'package:samadhan_app/pages/center_selection_page.dart';
import 'package:samadhan_app/providers/auth_provider.dart';
import 'package:samadhan_app/providers/student_provider.dart';
import 'package:samadhan_app/providers/attendance_provider.dart';
import 'package:samadhan_app/providers/volunteer_provider.dart';
import 'package:samadhan_app/providers/export_provider.dart';
import 'package:samadhan_app/providers/user_provider.dart';
import 'package:samadhan_app/providers/notification_provider.dart';
import 'package:samadhan_app/providers/offline_sync_provider.dart';
import 'package:samadhan_app/providers/event_provider.dart';
import 'package:samadhan_app/providers/schedule_provider.dart';
import 'package:samadhan_app/l10n/app_localizations.dart';

import 'package:samadhan_app/services/face_recognition_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FaceRecognitionService().loadModel();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()..fetchStudents()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()..fetchAttendanceRecords()),
        ChangeNotifierProvider(create: (_) => VolunteerProvider()..fetchReports()),
        ChangeNotifierProvider(create: (context) => UserProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..loadNotifications()),
        ChangeNotifierProvider(create: (_) => OfflineSyncProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()..loadEvents()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()..loadSchedules()),
        Provider(create: (context) => ExportProvider(Provider.of<StudentProvider>(context, listen: false))),
      ],
      child: Consumer2<AuthProvider, UserProvider>( // Consume both providers
        builder: (ctx, auth, userProvider, _) => MaterialApp(
          title: 'SARAL',
          theme: ThemeData(
            primarySwatch: Colors.indigo,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              primary: Colors.indigo,
              secondary: Colors.amber,
              background: Colors.grey[50],
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 2,
            ),
            useMaterial3: true,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(userProvider.userSettings.language.toLowerCase().substring(0, 2)), // Set locale from provider
          home: auth.isAuthenticated ? const CenterSelectionPage() : const LoginPage(),
        ),
      ),
    );
  }
}
