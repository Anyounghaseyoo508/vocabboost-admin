import 'package:flutter/material.dart';
import 'admin_add_question_screen.dart';
import '../../admin_import_screen.dart';
import '../controller/admin_exam_management_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// _TestSetCard
// ─────────────────────────────────────────────────────────────────────────────
class _TestSetCard extends StatelessWidget {
  final int testId;
  final String title;
  final bool isPublished;
  final Future<int> countFuture;
  final VoidCallback onTap;
  final Future<void> Function() onPublish;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TestSetCard({
    super.key,
    required this.testId,
    required this.title,
    required this.isPublished,
    required this.countFuture,
    required this.onTap,
    required this.onPublish,
    required this.onRename,
    required this.onDelete,
  });

  static const int _totalQ = 200;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: countFuture,
      builder: (_, snap) {
        final count    = snap.data ?? 0;
        final progress = (count / _totalQ).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: Colors.blueAccent.shade700,
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('$testId',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('$count / $_totalQ ข้อ',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ])),
                  _statusBadge(),
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'publish') await onPublish();
                      if (val == 'rename')  onRename();
                      if (val == 'delete')  onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'publish', child: Row(children: [
                        Icon(isPublished ? Icons.visibility_off : Icons.visibility, size: 18),
                        const SizedBox(width: 8),
                        Text(isPublished ? 'ซ่อน' : 'เผยแพร่'),
                      ])),
                      const PopupMenuItem(value: 'rename', child: Row(children: [
                        Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('แก้ไขชื่อ')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('ลบชุดข้อสอบ', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade100,
                        color: progress >= 1.0 ? Colors.green.shade400 : Colors.blue.shade400,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${(progress * 100).toInt()}%',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: progress >= 1.0
                              ? Colors.green.shade600 : Colors.grey.shade500)),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isPublished ? Colors.green.shade50 : Colors.orange.shade50,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: isPublished ? Colors.green.shade200 : Colors.orange.shade200),
    ),
    child: Text(isPublished ? 'Published' : 'Draft',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold,
            color: isPublished ? Colors.green.shade700 : Colors.orange.shade700)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AdminExamManagementScreen
// ─────────────────────────────────────────────────────────────────────────────
class AdminExamManagementScreen extends StatefulWidget {
  const AdminExamManagementScreen({super.key});

  @override
  State<AdminExamManagementScreen> createState() =>
      _AdminExamManagementScreenState();
}

class _AdminExamManagementScreenState extends State<AdminExamManagementScreen> {
  late final AdminExamManagementController _ctrl;

  static const double _wideBreakpoint = 900;

  @override
  void initState() {
    super.initState();
    _ctrl = AdminExamManagementController();
    _ctrl.onSnack = (msg) => _showSnack(msg);
    _ctrl.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isWide =>
      MediaQuery.of(context).size.width >= _wideBreakpoint;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _ctrl.currentLevel == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _ctrl.goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: _buildAppBar(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
              key: ValueKey(_ctrl.currentLevel), child: _buildContent()),
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_ctrl.getAppBarTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        if (_ctrl.currentLevel > 0)
          Text(_ctrl.getAppBarSubtitle(),
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.normal)),
      ]),
      leading: _ctrl.currentLevel > 0
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: _ctrl.goBack)
          : const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.quiz_rounded)),
      actions: [
        if (_ctrl.currentLevel == 0) ...[
          // ── Import CSV ──────────────────────────────────────────────────────
          Tooltip(
            message: 'นำเข้า CSV',
            child: IconButton(
              icon: const Icon(Icons.upload_file_rounded),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AdminImportScreen())),
            ),
          ),
          // ── สร้างชุดข้อสอบ ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _showCreateTestDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_isWide ? 'สร้างชุดข้อสอบ' : 'สร้าง'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blueAccent.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────────
  Widget? _buildFAB() {
    if (_ctrl.currentLevel != 2) return null;
    return FloatingActionButton.extended(
      onPressed: () => _navigateToAdd(null),
      backgroundColor: Colors.blueAccent.shade700,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('เพิ่มข้อสอบ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // ── Content Router ───────────────────────────────────────────────────────────
  Widget _buildContent() {
    switch (_ctrl.currentLevel) {
      case 0:  return _buildTestSetList();
      case 1:  return _buildPartSelector();
      case 2:  return _buildQuestionList();
      default: return const SizedBox.shrink();
    }
  }

  // ── Level 0: Test Set List ───────────────────────────────────────────────────
  Widget _buildTestSetList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ctrl.examSetsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final sets = snapshot.data ?? [];

        if (sets.isEmpty) return _emptyState(
            'ยังไม่มีชุดข้อสอบ\nกดปุ่ม "สร้างชุดข้อสอบ" เพื่อเริ่ม',
            Icons.library_books_outlined);

        if (_isWide) {
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 2.8,
                crossAxisSpacing: 14, mainAxisSpacing: 0),
            itemCount: sets.length,
            itemBuilder: (_, i) => _buildTestSetCard(sets[i]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: sets.length,
          itemBuilder: (_, i) => _buildTestSetCard(sets[i]),
        );
      },
    );
  }

  Widget _buildTestSetCard(Map<String, dynamic> s) {
    final testId    = s['test_id'] as int;
    final title     = s['title'] as String? ?? 'ไม่มีชื่อ';
    final published = s['is_published'] == true;

    return _TestSetCard(
      key: ValueKey(testId), testId: testId, title: title, isPublished: published,
      countFuture: _ctrl.questionCount(testId),
      onTap:     () => _ctrl.selectTestSet(testId, title),
      onPublish: () => _ctrl.togglePublish(testId, published),
      onRename:  () => _showRenameDialog(s),
      onDelete:  () => _confirmDeleteSet(testId),
    );
  }

  // ── Level 1: Part Selector ───────────────────────────────────────────────────
  Widget _buildPartSelector() {
    final crossCount = _isWide ? 4 : 2;
    final ratio      = _isWide ? 1.5 : 1.3;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ctrl.practiceTestStream,
      builder: (_, snap) {
        final all = snap.data
            ?.where((e) => e['test_id'] == _ctrl.selectedTestId)
            .toList() ?? [];

        return GridView.builder(
          padding: EdgeInsets.all(_isWide ? 24 : 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount, childAspectRatio: ratio,
              crossAxisSpacing: 14, mainAxisSpacing: 14),
          itemCount: 7,
          itemBuilder: (_, i) {
            final p           = i + 1;
            final count       = all.where((e) => e['part'] == p).length;
            final isListening = p <= 4;
            return _PartCard(
              part: p, count: count, isListening: isListening,
              icon: _partIcon(p), partName: _ctrl.partName(p),
              onTap: () => _ctrl.selectPart(p),
            );
          },
        );
      },
    );
  }

  // ── Level 2: Question List ───────────────────────────────────────────────────
  Widget _buildQuestionList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ctrl.practiceTestStream,
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = _ctrl.filterAndSort(snap.data!);
        if (docs.isEmpty) return _emptyState(
            'ยังไม่มีข้อสอบใน Part ${_ctrl.selectedPart}\nกด + เพื่อเพิ่มข้อแรก',
            Icons.quiz_outlined);

        final groups = _ctrl.groupByPassage(docs);

        Widget listView(EdgeInsets padding) => ListView.builder(
          padding: padding,
          itemCount: groups.length,
          itemBuilder: (_, i) {
            final g = groups[i];
            return g['isGroup'] == true
                ? _buildPassageGroupCard(g)
                : _buildQuestionCard(g['item'] as Map<String, dynamic>);
          },
        );

        if (_isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: listView(const EdgeInsets.fromLTRB(24, 20, 24, 100)),
            ),
          );
        }
        return listView(const EdgeInsets.fromLTRB(14, 14, 14, 100));
      },
    );
  }

  // ── Passage Group Card ───────────────────────────────────────────────────────
  Widget _buildPassageGroupCard(Map<String, dynamic> g) {
    final items      = g['items'] as List<Map<String, dynamic>>;
    final gId        = g['groupId'] as String;
    final qNos       = items.map((e) => 'Q${e['question_no']}').join(', ');
    final transcript = items.first['transcript']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade100, width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.purple.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.article_rounded,
                color: Colors.purple.shade600, size: 20),
          ),
          title: Text('Group: $gId',
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700, fontSize: 13)),
          subtitle: Text('$qNos · ${items.length} ข้อ',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          children: [
            if (transcript.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  transcript.length > 300
                      ? '${transcript.substring(0, 300)}...'
                      : transcript,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: _buildQuestionCard(item, compact: true),
                )),
          ],
        ),
      ),
    );
  }

  // ── Question Card ────────────────────────────────────────────────────────────
  Widget _buildQuestionCard(Map<String, dynamic> item, {bool compact = false}) {
    final hasAudio       = item['audio_url']?.toString().isNotEmpty == true;
    final hasImage       = item['image_url']?.toString().isNotEmpty == true;
    final hasExplanation = item['explanation']?.toString().trim().isNotEmpty == true;
    final hasCategory    = item['category']?.toString().trim().isNotEmpty == true;
    final qText          = item['question_text']?.toString().trim() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 4 : 8),
      decoration: BoxDecoration(
        color: compact ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: compact
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6, offset: const Offset(0, 2))],
        border: compact ? Border.all(color: Colors.grey.shade200) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: Colors.blueAccent.shade700,
          child: Text('${item['question_no']}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        title: Text(
          qText.isNotEmpty ? qText : '(Media / Passage Question)',
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 4, runSpacing: 4, children: [
            _badge('ANS: ${item['correct_answer'] ?? '?'}', Colors.indigo),
            if (hasCategory) _badge(item['category'], Colors.teal),
            if (hasAudio)    _badge('🎧', Colors.orange),
            if (hasImage)    _badge('📷', Colors.pink),
            if (!hasExplanation) _badge('ไม่มีเฉลย', Colors.red),
          ]),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit')   _navigateToAdd(item);
            if (val == 'delete') _confirmDelete(item['id']);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8), Text('แก้ไข')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('ลบ', style: TextStyle(color: Colors.red))])),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────────
  void _showCreateTestDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('สร้างชุดข้อสอบใหม่',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อชุดข้อสอบ (เช่น ETS 2024 Vol.1)',
            border: OutlineInputBorder(),
            helperText: 'Test ID จะถูกกำหนดอัตโนมัติ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { ctrl.dispose(); Navigator.pop(ctx); },
            child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              ctrl.dispose(); Navigator.pop(ctx);
              await _ctrl.createTestSet(name);
            },
            child: const Text('สร้าง')),
        ],
      ),
    );
  }

  void _showRenameDialog(Map<String, dynamic> s) {
    final ctrl   = TextEditingController(text: s['title']);
    final testId = s['test_id'] as int;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('แก้ไขชื่อชุดข้อสอบ'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'ชื่อใหม่', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () async {
              final t = ctrl.text.trim();
              ctrl.dispose(); Navigator.pop(ctx);
              await _ctrl.renameTestSet(testId, t);
            },
            child: const Text('บันทึก')),
        ],
      ),
    );
  }

  void _confirmDeleteSet(int testId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบชุดข้อสอบ?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Test ID: $testId และข้อสอบทั้งหมดจะถูกลบถาวร'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _ctrl.deleteTestSet(testId);
            },
            child: const Text('ลบทั้งหมด')),
        ],
      ),
    );
  }

  void _confirmDelete(dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบข้อสอบ?'),
        content: const Text('ข้อมูลที่ลบไปแล้วจะไม่สามารถกู้คืนได้'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _ctrl.deleteQuestion(id);
            },
            child: const Text('ลบ')),
        ],
      ),
    );
  }

  Future<void> _navigateToAdd(Map<String, dynamic>? item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAddQuestionScreen(
          editData: item,
          initialData: item == null
              ? {
                  'test_id':    _ctrl.selectedTestId,
                  'part':       _ctrl.selectedPart ?? 1,
                  'test_title': _ctrl.selectedTestTitle,
                }
              : null,
        ),
      ),
    );
  }

  // ── UI Helpers ───────────────────────────────────────────────────────────────
  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Text(text,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _emptyState(String msg, IconData icon) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 72, color: Colors.grey.shade200),
      const SizedBox(height: 16),
      Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.grey.shade400, height: 1.6, fontSize: 14)),
    ]),
  );

  IconData _partIcon(int p) {
    const icons = [
      Icons.image_rounded, Icons.record_voice_over_rounded,
      Icons.people_rounded, Icons.speaker_rounded,
      Icons.spellcheck_rounded, Icons.text_fields_rounded,
      Icons.menu_book_rounded,
    ];
    return icons[p - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PartCard — extracted widget เพื่อให้ hover effect ทำงานได้บนเว็บ
// ─────────────────────────────────────────────────────────────────────────────
class _PartCard extends StatefulWidget {
  final int part, count;
  final bool isListening;
  final IconData icon;
  final String partName;
  final VoidCallback onTap;
  const _PartCard({
    required this.part, required this.count, required this.isListening,
    required this.icon, required this.partName, required this.onTap,
  });
  @override
  State<_PartCard> createState() => _PartCardState();
}

class _PartCardState extends State<_PartCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isListening
        ? Colors.orange.shade700 : Colors.blue.shade700;
    final bg     = widget.isListening
        ? Colors.orange.shade50  : Colors.blue.shade50;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: accent.withValues(alpha: _hovered ? 0.15 : 0.05),
                  blurRadius: _hovered ? 14 : 6,
                  offset: const Offset(0, 3))],
              border: _hovered
                  ? Border.all(color: accent.withValues(alpha: 0.3))
                  : null,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(widget.icon, color: accent, size: 22),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.isListening ? 'L' : 'R',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold, color: accent)),
                ),
              ]),
              const Spacer(),
              Text('Part ${widget.part}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(widget.partName,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 4),
              Text('${widget.count} ข้อ',
                  style: TextStyle(
                      fontSize: 12, color: accent, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}
