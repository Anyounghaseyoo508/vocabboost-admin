import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_guard.dart';
import 'admin_login_screen.dart';
import 'admin_splash_screen.dart';
import 'screens/admin/Exam Management/screens/admin_add_question_screen.dart';
import 'screens/admin/Exam Management/screens/admin_exam_management_screen.dart';
import 'screens/admin/Vocabbulary Management/screens/admin_vocab_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/admin_import_screen.dart';
import 'screens/admin/admin_monitoring_screen.dart';
import 'screens/admin/admin_notification_screen.dart';
import 'screens/admin/admin_sheet_management_screen.dart';
import 'screens/admin/admin_user_management_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const AdminWebApp());
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VocabBoost Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A5F)),
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const AdminSplashScreen(),
        '/login': (_) => const AdminLoginScreen(),
        '/admin': (_) => const AdminGuard(child: AdminHomeScreen()),
        '/admin_home': (_) => const AdminGuard(child: AdminHomeScreen()),
        '/admin/exams': (_) =>
            const AdminGuard(child: AdminExamManagementScreen()),
        '/admin/add': (_) =>
            const AdminGuard(child: AdminAddQuestionScreen()),
        '/admin/import': (_) =>
            const AdminGuard(child: AdminImportScreen()),
        '/admin/sheets': (_) =>
            const AdminGuard(child: AdminSheetManagementScreen()),
        '/admin/vocab': (_) => const AdminGuard(child: AdminVocabScreen()),
        '/admin/monitoring': (_) =>
            const AdminGuard(child: AdminMonitoringScreen()),
        '/admin/users': (_) =>
            const AdminGuard(child: AdminUserManagementScreen()),
        '/admin/notifications': (_) =>
            const AdminGuard(child: AdminNotificationScreen()),
      },
    );
  }
}
