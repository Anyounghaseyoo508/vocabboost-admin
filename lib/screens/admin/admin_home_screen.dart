import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ──────────────────────────────────────────────────────────────────────────────
// AdminHomeScreen — เพิ่ม Activity Timeout สำหรับ Admin
// ถ้า Admin ไม่มีการคลิก/แตะนาน 30 นาที → logout อัตโนมัติ
// ──────────────────────────────────────────────────────────────────────────────

// ── ค่า timeout: 30 นาที (หน่วยเป็นนาที) ────────────────────────────────────
// ตอนเทส ให้เปลี่ยนเป็น 1 แล้วเปลี่ยนกลับมา 30 ตอนใช้จริง
const int _kAdminTimeoutMinutes = 30;

class AdminHomeScreen extends StatefulWidget {
  // ← เปลี่ยนจาก StatelessWidget เป็น StatefulWidget เพื่อจัดการ Timer
  const AdminHomeScreen({super.key});

  static const double _sidebarBreakpoint = 900;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with WidgetsBindingObserver {
  // WidgetsBindingObserver ใช้ detect ว่าแอปกลับมา foreground (เปิด tab กลับมาบน web)

  Timer? _timeoutTimer; // Timer นับเวลา inactivity
  DateTime _lastActivity = DateTime.now(); // เวลา activity ล่าสุด

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // เริ่ม observe app lifecycle
    _startTimer(); // เริ่มจับเวลา
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // หยุด observe
    _timeoutTimer?.cancel(); // ยกเลิก timer ป้องกัน memory leak
    super.dispose();
  }

  // ── เรียกทุกครั้งที่ app เปลี่ยน state (เช่น กลับมาจาก background) ────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // กลับมาจาก background หรือเปิด tab กลับมา → ตรวจ timeout ทันที
      _checkTimeout();
    }
  }

  // ── เริ่ม Timer ตรวจทุก 1 นาที ───────────────────────────────────────────
  void _startTimer() {
    _timeoutTimer?.cancel(); // cancel timer เก่าถ้ามี
    _timeoutTimer = Timer.periodic(
      const Duration(minutes: 1), // ตรวจทุก 1 นาที
      (_) => _checkTimeout(),
    );
  }

  // ── Reset เวลา activity ทุกครั้งที่ Admin คลิก/แตะ ───────────────────────
  void _resetActivity() {
    _lastActivity = DateTime.now();
  }

  // ── ตรวจว่าหมดเวลา inactivity หรือยัง ───────────────────────────────────
  Future<void> _checkTimeout() async {
    final elapsed = DateTime.now().difference(_lastActivity);

    if (elapsed.inMinutes >= _kAdminTimeoutMinutes) {
      // หมดเวลา → logout
      _timeoutTimer?.cancel();
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        // แสดง dialog แจ้งก่อน redirect ไป login
        showDialog(
          context: context,
          barrierDismissible: false, // กด outside ไม่ได้
          builder: (_) => AlertDialog(
            title: const Text('Session หมดอายุ'),
            content: const Text(
                'คุณไม่มีการใช้งานนานเกินไป กรุณาเข้าสู่ระบบใหม่'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // ปิด dialog
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                },
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.of(context).size.width >= AdminHomeScreen._sidebarBreakpoint;

    // ── Listener จับทุก gesture ของ Admin ────────────────────────────────────
    // onPointerDown จะ fire ทุกครั้งที่ Admin คลิก/แตะที่ใดก็ได้บนหน้า
    // แล้วเรียก _resetActivity() เพื่อ reset timer
    return Listener(
      onPointerDown: (_) => _resetActivity(), // ← จับ click/tap แล้ว reset timer
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: isWide ? _WideLayout() : _NarrowLayout(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wide layout (≥900px) — Sidebar + Content
// ─────────────────────────────────────────────────────────────────────────────
class _WideLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AdminSidebar(),
        Expanded(child: _DashboardBody()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Narrow layout (<900px) — Standard Scaffold with AppBar
// ─────────────────────────────────────────────────────────────────────────────
class _NarrowLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/vocabboost_logo_v3.png',
              width: 30,
              height: 30,
            ),
            const SizedBox(width: 8),
            const Text('VocabBoost Admin',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [_LogoutButton()],
      ),
      drawer: Drawer(
        child: _AdminSidebar(isDrawer: true),
      ),
      body: _DashboardBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _AdminSidebar extends StatelessWidget {
  final bool isDrawer;
  const _AdminSidebar({this.isDrawer = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: double.infinity,
      color: const Color(0xFF1E3A5F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo / Brand ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            child: Row(children: [
              Image.asset(
                'assets/images/vocabboost_logo_v3.png',
                width: 42,
                height: 42,
              ),
              const SizedBox(width: 12),
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VocabBoost',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text('Admin Panel',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
            ]),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 8),

          // ── Nav Items ─────────────────────────────────────────────────────
          _navItem(context,
              icon: Icons.dashboard_rounded,
              label: 'ภาพรวม',
              route: '/admin'),
          _navItem(context,
              icon: Icons.quiz_rounded,
              label: 'จัดการข้อสอบ',
              route: '/admin/exams'),
          _navItem(context,
              icon: Icons.library_books_rounded,
              label: 'ชีทสรุป',
              route: '/admin/sheets'),
          _navItem(context,
              icon: Icons.translate_rounded,
              label: 'คำศัพท์',
              route: '/admin/vocab'),
          _navItem(context,
              icon: Icons.analytics_rounded,
              label: 'ติดตามผู้ใช้',
              route: '/admin/monitoring'),
          _navItem(context,
              icon: Icons.manage_accounts_rounded,
              label: 'จัดการผู้ใช้',
              route: '/admin/users'),
          _navItem(context,
              icon: Icons.notifications_active_rounded,
              label: 'แจ้งเตือน',
              route: '/admin/notifications'),

          const Spacer(),

          // ── Bottom: Logout ─────────────────────────────────────────────────
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _LogoutButton(fullWidth: true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final isActive = currentRoute == route ||
        (route == '/admin/exams' && currentRoute.startsWith('/admin/exam'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () {
          if (Navigator.canPop(context)) Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: Colors.white.withValues(alpha: 0.2))
                : null,
          ),
          child: Row(children: [
            Icon(icon,
                color: isActive ? Colors.white : Colors.white60, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Body — เหมือนเดิมทุกอย่าง ไม่ได้แก้
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >=
        AdminHomeScreen._sidebarBreakpoint;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 32 : 20),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('ยินดีต้อนรับ 👋',
                    style: TextStyle(
                        fontSize: isWide ? 26 : 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3A5F))),
                const SizedBox(height: 4),
                Text('Admin Panel',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ])),
        ]),
        const SizedBox(height: 28),

        // ── Stats Row ────────────────────────────────────────────────────────
        _StatsRow(),
        const SizedBox(height: 28),

        // ── Quick Actions ────────────────────────────────────────────────────
        const Text('เมนูหลัก',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F))),
        const SizedBox(height: 14),
        _buildMenuGrid(context, isWide),
      ]),
    );
  }

  Widget _buildMenuGrid(BuildContext context, bool isWide) {
    final items = _menuItems(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isWide ? 1.3 : 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuCard(item: items[i]),
    );
  }
}

List<_MenuItem> _menuItems(BuildContext context) {
  return [
    _MenuItem(
      icon: Icons.quiz_rounded,
      title: 'จัดการข้อสอบ',
      subtitle: 'เพิ่ม แก้ไข เผยแพร่ข้อสอบ',
      gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
      onTap: () => Navigator.pushNamed(context, '/admin/exams'),
    ),
    _MenuItem(
      icon: Icons.translate_rounded,
      title: 'คำศัพท์',
      subtitle: 'จัดการคลังคำศัพท์',
      gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
      onTap: () => Navigator.pushNamed(context, '/admin/vocab'),
    ),
    _MenuItem(
      icon: Icons.library_books_rounded,
      title: 'ชีทสรุป',
      subtitle: 'อัปโหลดและจัดการชีท',
      gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
      onTap: () => Navigator.pushNamed(context, '/admin/sheets'),
    ),
    _MenuItem(
      icon: Icons.analytics_rounded,
      title: 'ติดตามผู้ใช้',
      subtitle: 'ดูสถิติการเรียน',
      gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF7043)]),
      onTap: () => Navigator.pushNamed(context, '/admin/monitoring'),
    ),
    _MenuItem(
      icon: Icons.manage_accounts_rounded,
      title: 'จัดการผู้ใช้',
      subtitle: 'ดูและแก้ไขข้อมูล user',
      gradient: const LinearGradient(
          colors: [Color(0xFF37474F), Color(0xFF78909C)]),
      onTap: () => Navigator.pushNamed(context, '/admin/users'),
    ),
    _MenuItem(
      icon: Icons.notifications_active_rounded,
      title: 'แจ้งเตือน',
      subtitle: 'ส่งประกาศถึงผู้ใช้',
      gradient: const LinearGradient(
          colors: [Color(0xFFC62828), Color(0xFFEF5350)]),
      onTap: () => Navigator.pushNamed(context, '/admin/notifications'),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Row — ดึงข้อมูลจริงจาก Supabase (เหมือนเดิม)
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatefulWidget {
  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  final _supabase = Supabase.instance.client;
  int _totalSets = 0;
  int _totalQuestions = 0;
  int _publishedSets = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sets = await _supabase.from('exam_sets').select('is_published');
      final questions = await _supabase.from('practice_test').select('id');
      if (mounted)
        setState(() {
          _totalSets = (sets as List).length;
          _publishedSets =
              (sets).where((e) => e['is_published'] == true).length;
          _totalQuestions = (questions as List).length;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >=
        AdminHomeScreen._sidebarBreakpoint;

    final stats = [
      _StatData('ชุดข้อสอบทั้งหมด', '$_totalSets', Icons.folder_rounded,
          const Color(0xFF1565C0)),
      _StatData('เผยแพร่แล้ว', '$_publishedSets', Icons.visibility_rounded,
          const Color(0xFF2E7D32)),
      _StatData('ข้อสอบทั้งหมด', '$_totalQuestions', Icons.quiz_rounded,
          const Color(0xFFE65100)),
    ];

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Wrap(
            spacing: 14,
            runSpacing: 14,
            children: stats
                .map((s) => SizedBox(
                      width: isWide
                          ? 200
                          : (MediaQuery.of(context).size.width - 54) / 2,
                      child: _StatCard(data: s),
                    ))
                .toList(),
          );
  }
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(data.icon, color: data.color, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data.value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: data.color)),
          Text(data.label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu Card (เหมือนเดิม)
// ─────────────────────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String title, subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}

class _MenuCard extends StatefulWidget {
  final _MenuItem item;
  const _MenuCard({required this.item});
  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: widget.item.onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: widget.item.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: widget.item.gradient.colors.first
                        .withValues(alpha: _hovered ? 0.4 : 0.2),
                    blurRadius: _hovered ? 16 : 8,
                    offset: const Offset(0, 4))
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(widget.item.icon, color: Colors.white, size: 30),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(widget.item.subtitle,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11)),
                    ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logout Button — reusable (เหมือนเดิม)
// ─────────────────────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final bool fullWidth;
  const _LogoutButton({this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    Future<void> logout() async {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }

    if (fullWidth) {
      return TextButton.icon(
        onPressed: logout,
        icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white60),
        label: const Text('ออกจากระบบ',
            style: TextStyle(color: Colors.white60, fontSize: 13)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.centerLeft,
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.logout_rounded),
      tooltip: 'ออกจากระบบ',
      onPressed: logout,
    );
  }
}