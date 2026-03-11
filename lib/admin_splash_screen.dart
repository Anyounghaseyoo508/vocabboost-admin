import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSplashScreen extends StatefulWidget {
  const AdminSplashScreen({super.key});

  @override
  State<AdminSplashScreen> createState() => _AdminSplashScreenState();
}

class _AdminSplashScreenState extends State<AdminSplashScreen> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final session = _supabase.auth.currentSession;

    if (!mounted) return;

    if (session == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }

    try {
      final profile = await _supabase
          .from('users')
          .select('role, is_active')
          .eq('id', session.user.id)
          .single();

      final isAdmin = profile['role'] == 'admin';
      final isActive = profile['is_active'] != false;

      if (!mounted) return;

      if (isAdmin && isActive) {
        Navigator.pushNamedAndRemoveUntil(context, '/admin', (_) => false);
        return;
      }

      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E3A5F),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
