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
  int _totalSubmissions = 0;
  double _avgScore = 0;
  List<_UserAggregate> _topUsers = [];
  List<_UserAggregate> _weakUsers = [];
  List<_TestExtrema> _testExtrema = [];
  List<Map<String, dynamic>> _recentIssues = [];
  Map<String, Map<String, dynamic>> _usersById = {};
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
          .select('user_id, test_id, score, total_questions');

      final submissions = List<Map<String, dynamic>>.from(submissionsResponse);
      final avgScore = submissions.isEmpty
          ? 0.0
          : submissions
                  .map((e) => (e['score'] as num?)?.toDouble() ?? 0)
                  .reduce((a, b) => a + b) /
              submissions.length;

      final byUser = <String, _UserAggregate>{};
      final byTest = <int, _TestExtrema>{};

      for (final row in submissions) {
        final userId = row['user_id'] as String?;
        final testId = (row['test_id'] as num?)?.toInt();
        final score = (row['score'] as num?)?.toDouble() ?? 0;
        final total = (row['total_questions'] as num?)?.toDouble() ?? 0;
        final accuracy = total == 0 ? 0.0 : (score / total) * 100;
        final userMap = userId == null ? null : usersById[userId];
        final name = (userMap?['display_name'] as String?)?.trim();
        final email = (userMap?['email'] as String?) ?? '-';
        final label = (name != null && name.isNotEmpty) ? name : email;

        if (userId != null) {
          final agg = byUser.putIfAbsent(
              userId, () => _UserAggregate(userLabel: label, email: email));
          agg.totalScore += score;
          agg.attempts += 1;
          agg.totalAccuracy += accuracy;
        }

        if (testId != null) {
          final extrema =
              byTest.putIfAbsent(testId, () => _TestExtrema(testId: testId));
          extrema.consume(row, label, email, score);
        }
      }

      final topUsers = byUser.values.toList()
        ..sort((a, b) => b.avgScore.compareTo(a.avgScore));
      final weakUsers = byUser.values.toList()
        ..sort((a, b) => a.avgAccuracy.compareTo(b.avgAccuracy));
      final extremaList = byTest.values.toList()
        ..sort((a, b) => a.testId.compareTo(b.testId));

      List<Map<String, dynamic>> issues = [];
      try {
        final issuesResponse = await _supabase
            .from('user_issues')
            .select('user_id, description, status, created_at')
            .order('created_at', ascending: false)
            .limit(10);
        issues = List<Map<String, dynamic>>.from(issuesResponse);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _totalUsers = usersCountResponse.length;
        _activeUsers = activeCountResponse.length;
        _totalSubmissions = submissions.length;
        _avgScore = avgScore;
        _topUsers = topUsers.take(5).toList();
        _weakUsers = weakUsers.take(5).toList();
        _testExtrema = extremaList;
        _recentIssues = issues;
        _usersById = usersById;
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
        title: const Text('ภาพรวมผู้ใช้และผลสอบ'),
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
                          child: _statCard('ผู้ใช้ทั้งหมด', '$_totalUsers',
                              Icons.people, Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard('ผู้ใช้ Active', '$_activeUsers',
                              Icons.person, Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _statCard(
                              'จำนวนการส่งข้อสอบ',
                              '$_totalSubmissions',
                              Icons.assignment,
                              Colors.orange)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _statCard(
                              'คะแนนเฉลี่ยระบบ',
                              _avgScore.toStringAsFixed(1),
                              Icons.analytics,
                              Colors.purple)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Top Users (คะแนนเฉลี่ยสูงสุด)'),
                  if (_topUsers.isEmpty)
                    const Card(child: ListTile(title: Text('ยังไม่มีข้อมูล')))
                  else
                    ..._topUsers.map((u) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.emoji_events,
                                color: Colors.amber),
                            title: Text(u.userLabel),
                            subtitle: Text(
                                'Attempts: ${u.attempts} | Accuracy: ${u.avgAccuracy.toStringAsFixed(1)}%'),
                            trailing: Text(u.avgScore.toStringAsFixed(1)),
                          ),
                        )),
                  const SizedBox(height: 20),
                  _sectionTitle('Users ที่ควรติดตาม (Accuracy ต่ำสุด)'),
                  if (_weakUsers.isEmpty)
                    const Card(child: ListTile(title: Text('ยังไม่มีข้อมูล')))
                  else
                    ..._weakUsers.map((u) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber,
                                color: Colors.deepOrange),
                            title: Text(u.userLabel),
                            subtitle: Text('Attempts: ${u.attempts}'),
                            trailing:
                                Text('${u.avgAccuracy.toStringAsFixed(1)}%'),
                          ),
                        )),
                  const SizedBox(height: 20),
                  _sectionTitle('Max/Min แยกตามชุดข้อสอบ'),
                  if (_testExtrema.isEmpty)
                    const Card(
                        child: ListTile(title: Text('ยังไม่มีข้อมูลชุดข้อสอบ')))
                  else
                    ..._testExtrema.map(
                      (t) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Test #${t.testId}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(
                                  'สูงสุด: ${t.maxUserLabel} (${t.maxScore.toStringAsFixed(1)})'),
                              Text(
                                  'ต่ำสุด: ${t.minUserLabel} (${t.minScore.toStringAsFixed(1)})'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _sectionTitle('ปัญหาที่ผู้ใช้รายงานล่าสุด'),
                  if (_recentIssues.isEmpty)
                    const Card(
                        child: ListTile(title: Text('ไม่มีปัญหาที่รายงาน')))
                  else
                    ..._recentIssues.map((issue) {
                      final issueUserId = issue['user_id'] as String?;
                      final user =
                          issueUserId == null ? null : _usersById[issueUserId];
                      final displayName = user?['display_name'];
                      final email = user?['email'] ?? '-';
                      final userLabel =
                          (displayName is String && displayName.isNotEmpty)
                              ? displayName
                              : email;
                      return Card(
                        child: ListTile(
                          title: Text(userLabel),
                          subtitle: Text(issue['description'] ?? '-'),
                          trailing:
                              Chip(label: Text(issue['status'] ?? 'pending')),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _UserAggregate {
  final String userLabel;
  final String email;
  double totalScore = 0;
  double totalAccuracy = 0;
  int attempts = 0;

  _UserAggregate({required this.userLabel, required this.email});

  double get avgScore => attempts == 0 ? 0 : totalScore / attempts;
  double get avgAccuracy => attempts == 0 ? 0 : totalAccuracy / attempts;
}

class _TestExtrema {
  final int testId;
  double maxScore = -1;
  double minScore = 999999;
  String maxUserLabel = '-';
  String minUserLabel = '-';

  _TestExtrema({required this.testId});

  void consume(
      Map<String, dynamic> row, String userLabel, String email, double score) {
    if (score > maxScore) {
      maxScore = score;
      maxUserLabel = userLabel.isEmpty ? email : userLabel;
    }
    if (score < minScore) {
      minScore = score;
      minUserLabel = userLabel.isEmpty ? email : userLabel;
    }
  }
}
