import 'package:flutter/material.dart';
import '../../../../models/vocab_model.dart';
import '../controller/admin_vocab_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminVocabScreen — View only
// ทุก logic อยู่ใน AdminVocabController
// ─────────────────────────────────────────────────────────────────────────────
class AdminVocabScreen extends StatefulWidget {
  const AdminVocabScreen({super.key});

  @override
  State<AdminVocabScreen> createState() => _AdminVocabScreenState();
}

class _AdminVocabScreenState extends State<AdminVocabScreen> {
  late final AdminVocabController _ctrl;
  final TextEditingController _adminSearchController = TextEditingController();

  static const double _wideBreakpoint = 900;
  bool get _isWide => MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  void initState() {
    super.initState();
    _ctrl = AdminVocabController();
    _ctrl.onSnack = (msg, {isError = false, isWarning = false}) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red
            : isWarning
                ? Colors.orange
                : Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    };
    _ctrl.addListener(() { if (mounted) setState(() {}); });
    _ctrl.refreshData();
  }

  @override
  void dispose() {
    _adminSearchController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final docs = _ctrl.filteredData;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
      body: Column(children: [
        _buildSearchFilterBar(),
        _buildResultStrip(docs.length),
        const Divider(height: 1, color: Color(0xFFE8EDF2)),
        Expanded(child: _buildBody(docs)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('เพิ่มคำศัพท์',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: const Color(0xFF1E3A5F),
    foregroundColor: Colors.white,
    elevation: 0,
    title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('คลังคำศัพท์',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      Text('Vocabulary Management',
          style: TextStyle(fontSize: 11, color: Colors.white60,
              fontWeight: FontWeight.normal)),
    ]),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'รีเฟรช',
        onPressed: _ctrl.refreshData,
      ),
      const SizedBox(width: 4),
    ],
  );

  // ── Search + Filter Bar ───────────────────────────────────────────────────
  Widget _buildSearchFilterBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    child: Column(children: [
      // Search field
      TextField(
        controller: _adminSearchController,
        onChanged: _ctrl.setSearch,
        decoration: InputDecoration(
          hintText: 'ค้นหา ID, คำศัพท์ หรือ คำแปล...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _ctrl.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _adminSearchController.clear();
                    _ctrl.setSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF0F4F8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5)),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _buildLetterChips()),
        const SizedBox(width: 8),
        _buildCEFRDropdown(),
      ]),
    ]),
  );

  Widget _buildLetterChips() {
    final letters = ['All', ...List.generate(26, (i) => String.fromCharCode(65 + i))];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: letters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final l      = letters[i];
          final active = _ctrl.selectedLetter == l;
          return GestureDetector(
            onTap: () => _ctrl.setLetter(l),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF1E3A5F) : const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(20),
                border: active ? null : Border.all(color: Colors.grey.shade200),
              ),
              child: Text(l,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: active ? Colors.white : Colors.grey.shade600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCEFRDropdown() {
    final levels = ['All', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final sel    = _ctrl.selectedCEFR;
    final color  = AdminVocabController.cefrColor(sel);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: sel == 'All' ? const Color(0xFFF0F4F8) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: sel == 'All' ? Colors.grey.shade200 : color.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: sel,
          isDense: true,
          icon: Icon(Icons.expand_more_rounded, size: 16,
              color: sel == 'All' ? Colors.grey.shade500 : color),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: sel == 'All' ? Colors.grey.shade600 : color),
          items: levels
              .map((l) => DropdownMenuItem(
                    value: l, child: Text(l == 'All' ? 'CEFR' : l)))
              .toList(),
          onChanged: (v) => _ctrl.setCEFR(v!),
        ),
      ),
    );
  }

  // ── Result strip ──────────────────────────────────────────────────────────
  Widget _buildResultStrip(int count) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    color: Colors.white,
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('พบ $count คำ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F))),
      ),
      if (_ctrl.hasActiveFilter) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            _adminSearchController.clear();
            _ctrl.clearFilters();
          },
          child: Text('ล้างตัวกรอง',
              style: TextStyle(fontSize: 12, color: Colors.red.shade400,
                  decoration: TextDecoration.underline)),
        ),
      ],
    ]),
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(List<Map<String, dynamic>> docs) {
    if (_ctrl.isLoading) return const Center(child: CircularProgressIndicator());
    if (docs.isEmpty)    return _buildEmptyState();
    if (_isWide) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 3.2,
            crossAxisSpacing: 12, mainAxisSpacing: 0),
        itemCount: docs.length,
        itemBuilder: (_, i) => _buildVocabCard(docs[i]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: docs.length,
      itemBuilder: (_, i) => _buildVocabCard(docs[i]),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 72, color: Colors.grey.shade200),
      const SizedBox(height: 16),
      Text('ไม่พบคำศัพท์',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
              color: Colors.grey.shade400)),
      const SizedBox(height: 4),
      Text('ลองเปลี่ยนตัวกรองหรือคำค้นหาใหม่',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    ]),
  );

  // ── Vocab Card ─────────────────────────────────────────────────────────────
  Widget _buildVocabCard(Map<String, dynamic> data) {
    final v     = Vocabulary.fromMap(data);
    final color = AdminVocabController.cefrColor(v.cefr);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Center(child: Text(
            v.cefr.isEmpty ? '?' : v.cefr,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          )),
        ),
        title: Row(children: [
          Text(v.headword,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (v.pos.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(v.pos,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic)),
            ),
          ],
          if (v.readingEn.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(v.readingEn,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(children: [
            Expanded(child: Text(v.translationTH,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
            if (v.toeicCategory.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                child: Text(v.toeicCategory,
                    style: TextStyle(fontSize: 10, color: Colors.teal.shade700,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _actionBtn(icon: Icons.edit_outlined, color: const Color(0xFF1E3A5F),
              tooltip: 'แก้ไข', onTap: () => _openForm(context, data)),
          const SizedBox(width: 2),
          _actionBtn(icon: Icons.delete_outline_rounded, color: Colors.red,
              tooltip: 'ลบ', onTap: () => _confirmDelete(data['id'])),
        ]),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon, required Color color,
    required String tooltip, required VoidCallback onTap,
  }) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // FORM — Desktop Dialog (wide) / Bottom Sheet (mobile)
  // ─────────────────────────────────────────────────────────────────────────
  void _openForm(BuildContext context, Map<String, dynamic>? existingData) {
    if (_isWide) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        builder: (_) => _VocabFormDialog(
          ctrl: _ctrl,
          existingData: existingData,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _VocabFormSheet(
          ctrl: _ctrl,
          existingData: existingData,
        ),
      );
    }
  }

  // ── Delete Confirm ─────────────────────────────────────────────────────────
  void _confirmDelete(dynamic id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.delete_outline_rounded,
                color: Colors.red.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('ยืนยันการลบ?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Text('ต้องการลบคำศัพท์รหัส $id ใช่หรือไม่?\nข้อมูลที่ลบแล้วไม่สามารถกู้คืนได้',
            style: TextStyle(color: Colors.grey.shade600, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey.shade600))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _ctrl.deleteVocab(id);
            },
            child: const Text('ลบ')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VocabFormDialog — Desktop: full Dialog with 2-column layout
// ─────────────────────────────────────────────────────────────────────────────
class _VocabFormDialog extends StatefulWidget {
  final AdminVocabController ctrl;
  final Map<String, dynamic>? existingData;
  const _VocabFormDialog({required this.ctrl, required this.existingData});

  @override
  State<_VocabFormDialog> createState() => _VocabFormDialogState();
}

class _VocabFormDialogState extends State<_VocabFormDialog> {
  late final TextEditingController headwordC, posC, cefrC, readingEnC,
      readingThC, transThC, defThC, defEnC, exampleC, categoryC, synonymsC;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existingData != null
        ? Vocabulary.fromMap(widget.existingData!)
        : null;
    headwordC  = TextEditingController(text: v?.headword);
    posC       = TextEditingController(text: v?.pos);
    cefrC      = TextEditingController(text: v?.cefr);
    readingEnC = TextEditingController(text: v?.readingEn);
    readingThC = TextEditingController(text: v?.readingTh);
    transThC   = TextEditingController(text: v?.translationTH);
    defThC     = TextEditingController(text: v?.definitionTH);
    defEnC     = TextEditingController(text: v?.definitionEN);
    exampleC   = TextEditingController(text: v?.exampleSentence);
    categoryC  = TextEditingController(text: v?.toeicCategory);
    synonymsC  = TextEditingController(text: v?.synonyms);
  }

  @override
  void dispose() {
    for (final c in [headwordC, posC, cefrC, readingEnC, readingThC,
        transThC, defThC, defEnC, exampleC, categoryC, synonymsC]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _runAiFill() async {
    setState(() => _aiLoading = true);
    final ai = await widget.ctrl.fetchAiData(
        headwordC.text.trim(), posC.text.trim());
    if (ai != null && mounted) {
      setState(() {
        cefrC.text      = ai['CEFR'] ?? '';
        readingEnC.text = ai['Reading_EN'] ?? '';
        readingThC.text = ai['Reading_TH'] ?? '';
        transThC.text   = ai['Translation_TH'] ?? '';
        defThC.text     = ai['Definition_TH'] ?? '';
        defEnC.text     = ai['Definition_EN'] ?? '';
        exampleC.text   = ai['Example_Sentence'] ?? '';
        categoryC.text  = ai['TOEIC_Category'] ?? '';
        synonymsC.text  = ai['Synonyms'] ?? '';
      });
    }
    if (mounted) setState(() => _aiLoading = false);
  }

  Future<void> _save() async {
    final ok = await widget.ctrl.saveVocab(
      existingData:    widget.existingData,
      headword:        headwordC.text.trim(),
      pos:             posC.text.trim(),
      cefr:            cefrC.text.trim(),
      readingEn:       readingEnC.text.trim(),
      readingTh:       readingThC.text.trim(),
      translationTH:   transThC.text.trim(),
      definitionTH:    defThC.text.trim(),
      definitionEN:    defEnC.text.trim(),
      exampleSentence: exampleC.text.trim(),
      toeicCategory:   categoryC.text.trim(),
      synonyms:        synonymsC.text.trim(),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit   = widget.existingData != null;
    final isReady  = headwordC.text.trim().isNotEmpty && posC.text.trim().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A5F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.translate_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEdit ? 'แก้ไขคำศัพท์' : 'เพิ่มคำศัพท์ใหม่',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 17)),
                if (isEdit)
                  Text('ID: ${widget.existingData!['id']}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ])),
              // AI Fill Button
              StatefulBuilder(builder: (_, ss) {
                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isReady
                        ? const Color(0xFF6A1B9A)
                        : Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: (_aiLoading || !isReady) ? null : _runAiFill,
                  icon: _aiLoading
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('AI Fill',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                );
              }),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // ── Form Body (scrollable) ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [

                // ── Row 1: Headword + POS + CEFR ──────────────────────────
                _sectionLabel('ข้อมูลหลัก'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(flex: 3, child: _field(headwordC, 'คำศัพท์ (Headword) *',
                      onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _field(posC, 'POS (n., v.) *',
                      hint: 'เช่น v., n.',
                      onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _field(cefrC, 'CEFR', hint: 'A1–C2')),
                ]),

                // ── Row 2: Reading EN + TH ────────────────────────────────
                Row(children: [
                  Expanded(child: _field(readingEnC, 'Phonetic (EN)', hint: '/ɪɡˈzæmpəl/')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(readingThC, 'คำอ่าน (ไทย)', hint: 'อิก-แซม-เปิ้ล')),
                ]),

                const SizedBox(height: 4),
                _sectionLabel('ความหมาย'),
                const SizedBox(height: 10),

                // ── Row 3: Translation + Category ─────────────────────────
                Row(children: [
                  Expanded(flex: 2, child: _field(transThC, 'คำแปลไทย')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(categoryC, 'หมวด TOEIC', hint: 'Office, Finance...')),
                ]),

                // ── Row 4: Definition TH + EN ─────────────────────────────
                Row(children: [
                  Expanded(child: _field(defThC, 'คำจำกัดความ (ไทย)')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(defEnC, 'Definition (EN)')),
                ]),

                // ── Row 5: Example + Synonyms ─────────────────────────────
                Row(children: [
                  Expanded(flex: 2, child: _field(exampleC, 'ตัวอย่างประโยค')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(synonymsC, 'คำพ้อง', hint: 'word1, word2')),
                ]),
              ]),
            ),
          ),

          // ── Footer Buttons ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ยกเลิก',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('บันทึกข้อมูล',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: _save,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
            color: Colors.grey.shade500, letterSpacing: 0.8)),
  );

  Widget _field(TextEditingController ctrl, String label,
      {String? hint, void Function(String)? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF7F9FC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF1E3A5F), width: 1.5)),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _VocabFormSheet — Mobile: Bottom Sheet (single column เหมือนเดิม)
// ─────────────────────────────────────────────────────────────────────────────
class _VocabFormSheet extends StatefulWidget {
  final AdminVocabController ctrl;
  final Map<String, dynamic>? existingData;
  const _VocabFormSheet({required this.ctrl, required this.existingData});

  @override
  State<_VocabFormSheet> createState() => _VocabFormSheetState();
}

class _VocabFormSheetState extends State<_VocabFormSheet> {
  late final TextEditingController headwordC, posC, cefrC, readingEnC,
      readingThC, transThC, defThC, defEnC, exampleC, categoryC, synonymsC;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.existingData != null
        ? Vocabulary.fromMap(widget.existingData!)
        : null;
    headwordC  = TextEditingController(text: v?.headword);
    posC       = TextEditingController(text: v?.pos);
    cefrC      = TextEditingController(text: v?.cefr);
    readingEnC = TextEditingController(text: v?.readingEn);
    readingThC = TextEditingController(text: v?.readingTh);
    transThC   = TextEditingController(text: v?.translationTH);
    defThC     = TextEditingController(text: v?.definitionTH);
    defEnC     = TextEditingController(text: v?.definitionEN);
    exampleC   = TextEditingController(text: v?.exampleSentence);
    categoryC  = TextEditingController(text: v?.toeicCategory);
    synonymsC  = TextEditingController(text: v?.synonyms);
  }

  @override
  void dispose() {
    for (final c in [headwordC, posC, cefrC, readingEnC, readingThC,
        transThC, defThC, defEnC, exampleC, categoryC, synonymsC]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _runAiFill() async {
    setState(() => _aiLoading = true);
    final ai = await widget.ctrl.fetchAiData(
        headwordC.text.trim(), posC.text.trim());
    if (ai != null && mounted) {
      setState(() {
        cefrC.text      = ai['CEFR'] ?? '';
        readingEnC.text = ai['Reading_EN'] ?? '';
        readingThC.text = ai['Reading_TH'] ?? '';
        transThC.text   = ai['Translation_TH'] ?? '';
        defThC.text     = ai['Definition_TH'] ?? '';
        defEnC.text     = ai['Definition_EN'] ?? '';
        exampleC.text   = ai['Example_Sentence'] ?? '';
        categoryC.text  = ai['TOEIC_Category'] ?? '';
        synonymsC.text  = ai['Synonyms'] ?? '';
      });
    }
    if (mounted) setState(() => _aiLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isReady = headwordC.text.trim().isNotEmpty && posC.text.trim().isNotEmpty;
    final isEdit  = widget.existingData != null;

    Widget field(TextEditingController ctrl, String label,
        {String? hint, void Function(String)? onChanged}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: ctrl,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: label, hintText: hint,
              labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFF1E3A5F), width: 1.5)),
            ),
          ),
        );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 6,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          )),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.translate_rounded,
                  color: Color(0xFF1E3A5F), size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEdit ? 'แก้ไขคำศัพท์' : 'เพิ่มคำศัพท์ใหม่',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (isEdit)
                Text('ID: ${widget.existingData!['id']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ]),
          const SizedBox(height: 20),
          // Headword + AI Fill
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: field(headwordC, 'คำศัพท์ *',
                onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isReady
                      ? const Color(0xFF6A1B9A) : Colors.grey.shade200,
                  foregroundColor: isReady ? Colors.white : Colors.grey.shade400,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onPressed: (_aiLoading || !isReady) ? null : _runAiFill,
                icon: _aiLoading
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('AI Fill',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ]),
          Row(children: [
            Expanded(child: field(posC, 'POS *', hint: 'v., n.',
                onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: field(cefrC, 'CEFR', hint: 'A1–C2')),
          ]),
          Row(children: [
            Expanded(child: field(readingEnC, 'Reading (EN)')),
            const SizedBox(width: 10),
            Expanded(child: field(readingThC, 'คำอ่าน (ไทย)')),
          ]),
          field(transThC, 'คำแปลไทย'),
          field(defThC, 'คำจำกัดความ (ไทย)'),
          field(defEnC, 'คำจำกัดความ (Eng)'),
          field(exampleC, 'ตัวอย่างประโยค'),
          field(categoryC, 'หมวดหมู่ TOEIC'),
          field(synonymsC, 'คำพ้องความหมาย'),
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('บันทึกข้อมูล',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () async {
                final ok = await widget.ctrl.saveVocab(
                  existingData:    widget.existingData,
                  headword:        headwordC.text.trim(),
                  pos:             posC.text.trim(),
                  cefr:            cefrC.text.trim(),
                  readingEn:       readingEnC.text.trim(),
                  readingTh:       readingThC.text.trim(),
                  translationTH:   transThC.text.trim(),
                  definitionTH:    defThC.text.trim(),
                  definitionEN:    defEnC.text.trim(),
                  exampleSentence: exampleC.text.trim(),
                  toeicCategory:   categoryC.text.trim(),
                  synonyms:        synonymsC.text.trim(),
                );
                if (ok && mounted) Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}
