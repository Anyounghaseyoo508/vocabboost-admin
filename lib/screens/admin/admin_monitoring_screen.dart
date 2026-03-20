import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminMonitoringScreen extends StatefulWidget {
  const AdminMonitoringScreen({super.key});

  @override
  State<AdminMonitoringScreen> createState() => _AdminMonitoringScreenState();
}

class _AdminMonitoringScreenState extends State<AdminMonitoringScreen> {
  final _supabase = Supabase.instance.client;

  int _totalUsers = 0;
  int _activeUsers = 0;
  List<_UserScoreSummary> _topUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final usersCountResponse = await _supabase.from('users').select('id');
      final activeCountResponse =
          await _supabase.from('users').select('id').eq('is_active', true);
      final usersResponse =
          await _supabase.from('users').select('id, display_name, email');
      final usersById = <String, Map<String, dynamic>>{
        for (final row in usersResponse)
          row['id'] as String: Map<String, dynamic>.from(row as Map),
      };

      final submissionsResponse = await _supabase
          .from('exam_submissions')
          .select('user_id, score');

      final summariesByUser = <String, _UserScoreSummary>{};

      for (final row in submissionsResponse) {
        final map = Map<String, dynamic>.from(row as Map);
        final userId = map['user_id'] as String?;
        if (userId == null) continue;

        final score = (map['score'] as num?)?.toDouble() ?? 0;
        final userMap = usersById[userId];
        final name = (userMap?['display_name'] as String?)?.trim();
        final email = (userMap?['email'] as String?) ?? '-';
        final label = (name != null && name.isNotEmpty) ? name : email;

        final summary = summariesByUser.putIfAbsent(
          userId,
          () => _UserScoreSummary(
            userId: userId,
            userLabel: label,
            email: email,
          ),
        );
        summary.consume(score);
      }

      final topUsers = summariesByUser.values.toList()
        ..sort((a, b) {
          final maxCompare = b.maxScore.compareTo(a.maxScore);
          if (maxCompare != 0) return maxCompare;

          final minCompare = b.minScore.compareTo(a.minScore);
          if (minCompare != 0) return minCompare;

          return a.userLabel.toLowerCase().compareTo(b.userLabel.toLowerCase());
        });

      if (!mounted) return;
      setState(() {
        _totalUsers = usersCountResponse.length;
        _activeUsers = activeCountResponse.length;
        _topUsers = topUsers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ติดตามผู้ใช้'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/admin/notifications'),
            icon: const Icon(Icons.notifications_active),
            tooltip: 'ส่งแจ้งเตือน',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          'ผู้ใช้ทั้งหมด',
                          '$_totalUsers',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          'ผู้ใช้ Active',
                          '$_activeUsers',
                          Icons.person,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Top User'),
                  const SizedBox(height: 8),
                  if (_topUsers.isEmpty)
                    const Card(child: ListTile(title: Text('ยังไม่มีข้อมูล')))
                  else
                    ..._topUsers.map(
                      (user) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE8EEF7),
                            child: Icon(
                              Icons.emoji_events_outlined,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          title: Text(user.userLabel),
                          subtitle: Text(user.email),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Min ${user.minScore.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Max ${user.maxScore.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserScoreSummary {
  _UserScoreSummary({
    required this.userId,
    required this.userLabel,
    required this.email,
  });

  final String userId;
  final String userLabel;
  final String email;
  double minScore = double.infinity;
  double maxScore = double.negativeInfinity;

  void consume(double score) {
    if (score < minScore) minScore = score;
    if (score > maxScore) maxScore = score;
  }
}
