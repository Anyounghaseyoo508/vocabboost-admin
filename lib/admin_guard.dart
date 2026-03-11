import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminGuard extends StatefulWidget {
  const AdminGuard({super.key, required this.child});

  final Widget child;

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  final _supabase = Supabase.instance.client;
  late final Future<bool> _canAccessFuture = _canAccess();

  Future<bool> _canAccess() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      return false;
    }

    final profile = await _supabase
        .from('users')
        .select('role, is_active')
        .eq('id', session.user.id)
        .maybeSingle();

    if (profile == null) {
      return false;
    }

    return profile['role'] == 'admin' && profile['is_active'] != false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canAccessFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return widget.child;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        });

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
