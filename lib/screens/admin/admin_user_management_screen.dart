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
      final response = await _supabase
          .from('users')
          .select('id, email, display_name, role, is_active, created_at')
          .order('created_at', ascending: false);

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

  Future<void> _updateUser(Map<String, dynamic> user,
      {String? role, String? displayName, bool? isActive}) async {
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
              child: const Text('ยกเลิก')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('บันทึก')),
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
                      final isActive = user['is_active'] != false;
                      final role = (user['role'] ?? 'user') as String;
                      final email = user['email'] ?? '-';
                      final displayName = user['display_name'] ?? email;

                      return Card(
                        child: ListTile(
                          title: Text(displayName),
                          subtitle: Text(email),
                          leading: CircleAvatar(
                            backgroundColor: role == 'admin'
                                ? Colors.deepPurple
                                : Colors.blue,
                            child: Text(role == 'admin' ? 'A' : 'U',
                                style: const TextStyle(color: Colors.white)),
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
                                await _updateUser(user, isActive: !isActive);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                  value: 'edit_name',
                                  child: Text('แก้ชื่อโปรไฟล์')),
                              PopupMenuItem(
                                value: role == 'admin'
                                    ? 'make_user'
                                    : 'make_admin',
                                child: Text(role == 'admin'
                                    ? 'ปรับเป็น user'
                                    : 'ปรับเป็น admin'),
                              ),
                              PopupMenuItem(
                                value: 'toggle_active',
                                child: Text(isActive
                                    ? 'ปิดการใช้งานบัญชี'
                                    : 'เปิดการใช้งานบัญชี'),
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
}
