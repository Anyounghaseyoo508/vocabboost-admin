import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response =
          await _supabase.from('users').select().order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดผู้ใช้ไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _updateUser(
    Map<String, dynamic> user, {
    String? role,
    String? displayName,
    bool? isActive,
  }) async {
    try {
      await _supabase.from('users').update({
        if (role != null) 'role': role,
        if (displayName != null) 'display_name': displayName,
        if (isActive != null) 'is_active': isActive,
      }).eq('id', user['id']);

      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตผู้ใช้แล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _editName(Map<String, dynamic> user) async {
    final controller = TextEditingController(text: user['display_name'] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขชื่อผู้ใช้'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'ชื่อที่แสดง'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    await _updateUser(user, displayName: result);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _users.where((u) {
      if (query.isEmpty) return true;
      final email = '${u['email'] ?? ''}'.toLowerCase();
      final name = '${u['display_name'] ?? ''}'.toLowerCase();
      return email.contains(query) || name.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการผู้ใช้'),
        actions: [
          IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหา email หรือชื่อ',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final isEnabled = user['is_active'] != false;
                      final role = (user['role'] ?? 'user') as String;
                      final email = user['email'] ?? '-';
                      final displayName = user['display_name'] ?? email;
                      final activity = _resolveActivity(user);

                      return Card(
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(child: Text(displayName)),
                              _ActivityBadge(activity: activity),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(email),
                                const SizedBox(height: 4),
                                Text(
                                  'Role: $role | บัญชี: ${isEnabled ? 'เปิดใช้งาน' : 'ปิดใช้งาน'}',
                                ),
                                if (activity.detail != null) ...[
                                  const SizedBox(height: 4),
                                  Text(activity.detail!),
                                ],
                              ],
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: role == 'admin'
                                ? Colors.deepPurple
                                : Colors.blue,
                            child: Text(
                              role == 'admin' ? 'A' : 'U',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit_name') {
                                await _editName(user);
                              } else if (value == 'make_admin') {
                                await _updateUser(user, role: 'admin');
                              } else if (value == 'make_user') {
                                await _updateUser(user, role: 'user');
                              } else if (value == 'toggle_active') {
                                await _updateUser(user, isActive: !isEnabled);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit_name',
                                child: Text('แก้ชื่อโปรไฟล์'),
                              ),
                              PopupMenuItem(
                                value:
                                    role == 'admin' ? 'make_user' : 'make_admin',
                                child: Text(
                                  role == 'admin'
                                      ? 'ปรับเป็น user'
                                      : 'ปรับเป็น admin',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle_active',
                                child: Text(
                                  isEnabled
                                      ? 'ปิดการใช้งานบัญชี'
                                      : 'เปิดการใช้งานบัญชี',
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          dense: false,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  _UserActivityState _resolveActivity(Map<String, dynamic> user) {
    final isEnabled = user['is_active'] != false;
    final activityTime = _readActivityTime(user);

    if (!isEnabled) {
      return const _UserActivityState(
        label: 'Inactive',
        color: Colors.redAccent,
        detail: 'บัญชีถูกปิดการใช้งาน',
      );
    }

    if (activityTime == null) {
      return const _UserActivityState(
        label: 'Unknown',
        color: Colors.grey,
        detail: 'ไม่พบข้อมูล activity ล่าสุดในฐานข้อมูล',
      );
    }

    final now = DateTime.now().toUtc();
    final difference = now.difference(activityTime.toUtc());

    if (difference.inMinutes <= 5) {
      return _UserActivityState(
        label: 'Active now',
        color: Colors.green,
        detail: 'ใช้งานล่าสุด ${_formatRelative(difference)}',
      );
    }

    return _UserActivityState(
      label: 'Recently active',
      color: Colors.orange,
      detail: 'ใช้งานล่าสุด ${_formatRelative(difference)}',
    );
  }

  DateTime? _readActivityTime(Map<String, dynamic> user) {
    const candidateKeys = [
      'last_seen',
      'last_active_at',
      'last_sign_in_at',
    ];

    for (final key in candidateKeys) {
      final value = user[key];
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
    }
    return null;
  }

  String _formatRelative(Duration difference) {
    if (difference.inMinutes < 1) {
      return 'เมื่อสักครู่';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    }
    return '${difference.inDays} วันที่แล้ว';
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.activity});

  final _UserActivityState activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: activity.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        activity.label,
        style: TextStyle(
          color: activity.color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _UserActivityState {
  const _UserActivityState({
    required this.label,
    required this.color,
    this.detail,
  });

  final String label;
  final Color color;
  final String? detail;
}
