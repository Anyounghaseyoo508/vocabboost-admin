import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _isSending = false;
  String _target = 'all';
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final allUsers = await _supabase
          .from('users')
          .select('id, email, display_name')
          .eq('is_active', true)
          .order('email');
      final settings = await _supabase
          .from('user_settings')
          .select('user_id, notifications_enabled');

      final enabledByUser = <String, bool>{
        for (final s in settings)
          s['user_id'] as String: s['notifications_enabled'] != false,
      };

      final response = List<Map<String, dynamic>>.from(allUsers).where((u) {
        final userId = u['id'] as String;
        return enabledByUser[userId] ?? true;
      }).toList();

      if (!mounted) return;
      setState(() {
        _users = response;
      });
    } catch (_) {}
  }

  String _userLabel(Map<String, dynamic> user) {
    final displayName = user['display_name'] as String?;
    final email = user['email'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty)
      return '$displayName (${email ?? '-'})';
    return email ?? '-';
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกหัวข้อและข้อความให้ครบ')),
      );
      return;
    }

    if (_target == 'single' && _selectedUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เลือกผู้ใช้ปลายทาง')));
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_target == 'single') {
        await _supabase.from('user_notifications').insert({
          'user_id': _selectedUserId,
          'title': title,
          'body': body,
          'is_read': false,
        });
      } else {
        if (_users.isEmpty) await _loadUsers();
        if (_users.isNotEmpty) {
          final rows = _users
              .map(
                (u) => {
                  'user_id': u['id'],
                  'title': title,
                  'body': body,
                  'is_read': false,
                },
              )
              .toList();
          await _supabase.from('user_notifications').insert(rows);
        }
      }

      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งแจ้งเตือนสำเร็จ')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ส่งแจ้งเตือนไม่สำเร็จ: $e')));
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ส่งแจ้งเตือนผู้ใช้')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ปลายทาง',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('ผู้ใช้ทั้งหมด')),
                ButtonSegment(value: 'single', label: Text('ผู้ใช้รายคน')),
              ],
              selected: {_target},
              onSelectionChanged: (s) {
                setState(() {
                  _target = s.first;
                });
              },
            ),
            if (_target == 'single') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedUserId,
                items: _users
                    .map(
                      (u) => DropdownMenuItem<String>(
                        value: u['id'] as String,
                        child: Text(
                          _userLabel(u),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedUserId = v),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'เลือกผู้ใช้',
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'หัวข้อ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'ข้อความแจ้งเตือน',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSending ? null : _sendNotification,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('ส่งแจ้งเตือน'),
            ),
          ],
        ),
      ),
    );
  }
}
