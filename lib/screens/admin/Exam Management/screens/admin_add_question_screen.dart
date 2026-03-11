// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controller/admin_add_question_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminAddQuestionScreen
// ─────────────────────────────────────────────────────────────────────────────
class AdminAddQuestionScreen extends StatefulWidget {
  final Map<String, dynamic>? editData;
  final Map<String, dynamic>? initialData;

  const AdminAddQuestionScreen({super.key, this.editData, this.initialData});

  @override
  State<AdminAddQuestionScreen> createState() => _AdminAddQuestionScreenState();
}

class _AdminAddQuestionScreenState extends State<AdminAddQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AdminQuestionController _ctrl;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _ctrl = AdminQuestionController();
    _ctrl.onSnack = (msg) => _showSnack(msg);
    _ctrl.onSaved = () { if (mounted) Navigator.pop(context); };
    _ctrl.addListener(() { if (mounted) setState(() {}); });
    _ctrl.init(editData: widget.editData, initialData: widget.initialData);
  }

  @override
  void dispose() {
    _ctrl.dispose2();
    _ctrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.editData != null ? 'แก้ไขข้อสอบ' : 'เพิ่มข้อสอบ',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: (_ctrl.isLoading || _ctrl.isGeneratingAI) ? null : _onSave,
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            label: const Text('บันทึก',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(children: [
        Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card('📋 ข้อมูลพื้นฐาน', _buildBasicInfo()),
              const SizedBox(height: 12),
              if (_ctrl.selectedPart <= 4) ...[
                _card('🎧 ไฟล์เสียง', _buildMediaSection('audio')),
                const SizedBox(height: 12),
              ],
              if (_ctrl.selectedPart == 1 ||
                  _ctrl.selectedPart == 3 ||
                  _ctrl.selectedPart == 4 ||
                  _ctrl.selectedPart == 6) ...[
                _card('📷 รูปภาพ', _buildMediaSection('image')),
                const SizedBox(height: 12),
              ],
              _card(
                _ctrl.selectedPart <= 4 ? '📝 Transcript' : '📖 Passage / บทความ',
                _buildTranscriptSection(),
              ),
              const SizedBox(height: 12),
              if (_ctrl.selectedPart == 3 || _ctrl.selectedPart == 4 ||
                  _ctrl.selectedPart >= 6) ...[
                _card(
                  _ctrl.selectedPart >= 6 ? '🗂️ Passage Group & รูปภาพ' : '🔗 Passage Group',
                  _buildPassageGroupSection(),
                ),
                const SizedBox(height: 12),
              ],
              _card('❓ โจทย์และตัวเลือก', _buildQuestionSection()),
              const SizedBox(height: 12),
              _card('✅ เฉลยและคำอธิบาย', _buildAnswerSection()),
              const SizedBox(height: 80),
            ],
          ),
        ),
        if (_ctrl.isLoading)
          Container(
            color: Colors.black.withOpacity(0.35),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 14),
              Text(_ctrl.loadingMessage,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ])),
          ),
        if (_ctrl.isGeneratingAI && !_ctrl.isLoading)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: Colors.purple.shade700,
              child: const Row(children: [
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 14),
                Text('AI กำลังวิเคราะห์...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    );
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    _ctrl.saveData(widget.editData != null, widget.editData?['id'] as int?);
  }

  // ── Basic Info ──────────────────────────────────────────────────────────────
  Widget _buildBasicInfo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_ctrl.testTitle != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.folder_rounded, color: Colors.blue.shade600, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_ctrl.testTitle!,
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700, fontSize: 13))),
          ]),
        ),
      _field(_ctrl.qNoCtrl, 'ข้อที่ (No.)', isNumber: true),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
        value: _ctrl.selectedPart,
        decoration: _deco('TOEIC Part'),
        items: List.generate(7, (i) => DropdownMenuItem(
          value: i + 1, child: Text('Part ${i + 1}: ${_ctrl.partName(i + 1)}'),
        )),
        onChanged: (v) => _ctrl.onPartChanged(v!),
      ),
    ]);
  }

  // ── Media Section — 2 ปุ่ม / status card ───────────────────────────────────
  Widget _buildMediaSection(String type) {
    final isAudio  = type == 'audio';
    final urlCtrl  = isAudio ? _ctrl.audioUrlCtrl : _ctrl.imageUrlCtrl;
    final hasUrl   = urlCtrl.text.trim().isNotEmpty;
    final accent   = isAudio ? Colors.orange.shade700 : Colors.blue.shade700;
    final bgColor  = isAudio ? Colors.orange.shade50  : Colors.blue.shade50;
    final border   = isAudio ? Colors.orange.shade200 : Colors.blue.shade200;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── ยังไม่มีไฟล์ → 2 ปุ่มใหญ่ ──────────────────────────────────────────
      if (!hasUrl) ...[
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _ctrl.isLoading ? null : () => _ctrl.uploadFile(type),
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(isAudio ? 'อัปโหลดเสียงจากเครื่อง' : 'อัปโหลดรูปจากเครื่อง'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _ctrl.isLoading ? null : () => _browseStorage(type),
              icon: Icon(isAudio ? Icons.library_music_rounded : Icons.photo_library_rounded, size: 18),
              label: const Text('เลือกจาก Storage'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ]),
      ]

      // ── มีไฟล์แล้ว → status card + ⋮ เมนู ─────────────────────────────────
      else ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(children: [
            Icon(isAudio ? Icons.check_circle_rounded : Icons.image_rounded,
                color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAudio ? 'ไฟล์เสียงพร้อมแล้ว' : 'รูปภาพพร้อมแล้ว',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
              const SizedBox(height: 2),
              Text(
                urlCtrl.text.length > 60
                    ? '...${urlCtrl.text.substring(urlCtrl.text.length - 60)}'
                    : urlCtrl.text,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ])),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: accent),
              onSelected: (v) {
                if (v == 'upload') _ctrl.uploadFile(type);
                if (v == 'browse') _browseStorage(type);
                if (v == 'clear')  urlCtrl.clear();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'upload', child: Row(children: [
                  const Icon(Icons.cloud_upload_rounded, size: 16),
                  const SizedBox(width: 8), const Text('อัปโหลดไฟล์ใหม่'),
                ])),
                PopupMenuItem(value: 'browse', child: Row(children: [
                  Icon(isAudio ? Icons.library_music_rounded : Icons.photo_library_rounded, size: 16),
                  const SizedBox(width: 8), const Text('เลือกจาก Storage'),
                ])),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'clear', child: Row(children: [
                  const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('ลบออก', style: TextStyle(color: Colors.red)),
                ])),
              ],
            ),
          ]),
        ),

        if (!isAudio && (_ctrl.selectedPart == 6 || _ctrl.selectedPart == 7)) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _ctrl.isGeneratingAI ? null
                  : () => _ctrl.aiScanImages([urlCtrl.text]),
              icon: _ctrl.isGeneratingAI
                  ? const SizedBox(width: 15, height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple))
                  : const Icon(Icons.document_scanner_rounded, color: Colors.purple, size: 16),
              label: Text(_ctrl.isGeneratingAI
                  ? 'กำลังสแกน...' : 'AI Scan รูป → ใส่ Transcript',
                  style: const TextStyle(color: Colors.purple, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.purple),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
        ],
      ],

      if (isAudio) ...[
        const SizedBox(height: 12),
        _AudioTimingSection(
          audioUrl: _ctrl.audioUrlCtrl.text.trim(),
          startCtrl: _ctrl.startTimeCtrl,
          endCtrl: _ctrl.endTimeCtrl,
        ),
      ],
    ]);
  }

  // ── Transcript ──────────────────────────────────────────────────────────────
  Widget _buildTranscriptSection() {
    final hint = _ctrl.selectedPart <= 4
        ? 'พิมพ์ข้อความที่พูดในไฟล์เสียง...'
        : 'พิมพ์บทความ / Passage...';
    return _field(_ctrl.transcriptCtrl, hint, maxLines: 6, required: false);
  }

  // ── Passage Group ───────────────────────────────────────────────────────────
  Widget _buildPassageGroupSection() {
    final isPart67 = _ctrl.selectedPart >= 6;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200)),
        child: Text(
          isPart67
              ? '📌 ข้อแรกของกลุ่ม → สร้าง Group ใหม่ แล้วอัปโหลดรูป\n'
                '• ข้อถัดไปในกลุ่มเดิม → เลือก Group เดิม\n'
                '• Transcript = บทความที่ใช้ตอบโจทย์'
              : '📌 ข้อที่ฟังเสียงชุดเดียวกัน ให้เลือก Group เดียวกัน',
          style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.6),
        ),
      ),
      Row(children: [
        Expanded(child: _toggleBtn('สร้าง Group ใหม่', Icons.add_circle_outline,
            _ctrl.createNewGroup, () => _ctrl.setCreateNewGroup(true))),
        const SizedBox(width: 8),
        Expanded(child: _toggleBtn('เลือก Group เดิม', Icons.folder_open,
            !_ctrl.createNewGroup, () => _ctrl.setCreateNewGroup(false))),
      ]),
      const SizedBox(height: 14),
      if (_ctrl.createNewGroup)
        _buildNewGroupIdField(),
      if (!_ctrl.createNewGroup) ...[
        if (_ctrl.existingGroups.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200)),
            child: Text(
              'ยังไม่มี Passage Group ใน Part ${_ctrl.selectedPart}\nกด "สร้าง Group ใหม่" เพื่อเริ่ม',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            _groupChip('ไม่มี Group', null),
            ..._ctrl.existingGroups.map((g) => _groupChip(g, g)),
          ]),
        const SizedBox(height: 8),
      ],
      if (isPart67 && (_ctrl.createNewGroup || _ctrl.selectedPassageGroup != null)) ...[
        const Divider(height: 24),
        _buildPassageImageSection(),
      ],
    ]);
  }

  // ── New Group ID Input + Warning ────────────────────────────────────────────
  Widget _buildNewGroupIdField() {
    final tId  = _ctrl.testIdCtrl.text.trim();
    final part = _ctrl.selectedPart;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Description box ───────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text('รูปแบบ Group ID',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800)),
          ]),
          const SizedBox(height: 6),
          // แสดงตัวอย่างแบบ breakdown
          _groupIdFormatRow('t', '$tId', 'ชุดข้อสอบที่ $tId'),
          _groupIdFormatRow('p', '$part', 'Part $part'),
          _groupIdFormatRow('g', '?', 'ลำดับกลุ่ม (1, 2, 3...)'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ตัวอย่าง: t${tId}p${part}g1  หรือ  t${tId}p${part}g2',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '💡 ถ้าไม่กรอก ระบบจะ Auto-gen ให้อัตโนมัติ',
            style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
          ),
        ]),
      ),

      // ── Text field ─────────────────────────────────────────────────────────
      TextFormField(
        controller: _ctrl.newGroupCtrl,
        style: const TextStyle(fontSize: 14, fontFamily: 'monospace',
            fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: 'Group ID',
          hintText: 'เช่น t${tId}p${part}g3  (ว่าง = Auto-gen)',
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400,
              fontWeight: FontWeight.normal, fontFamily: 'monospace'),
          labelStyle: const TextStyle(fontSize: 13),
          filled: true,
          fillColor: Colors.grey.shade50,
          suffixIcon: _ctrl.checkingGroupId
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: Colors.orange.shade600)),
                )
              : _ctrl.newGroupCtrl.text.trim().isNotEmpty
                  ? (_ctrl.groupIdWarning != null
                      ? Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade600)
                      : Icon(Icons.check_circle_outline_rounded,
                          color: Colors.green.shade600))
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: _ctrl.groupIdWarning != null
                      ? Colors.orange.shade400
                      : Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: _ctrl.groupIdWarning != null
                      ? Colors.orange.shade500
                      : Colors.blue.shade400,
                  width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: (v) => _ctrl.checkGroupIdConflict(v),
      ),

      // ── Warning box (แสดงเมื่อ ID นั้นมีรูปใน passages แล้ว) ──────────────
      if (_ctrl.groupIdWarning != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_ctrl.groupIdWarning!,
                  style: TextStyle(fontSize: 12,
                      color: Colors.orange.shade900, height: 1.5)),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 4),
    ]);
  }

  Widget _groupIdFormatRow(String token, String value, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
              color: Colors.blue.shade700, shape: BoxShape.circle),
          child: Center(child: Text(token,
              style: const TextStyle(fontSize: 9, color: Colors.white,
                  fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4)),
          child: Text(value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800, fontFamily: 'monospace')),
        ),
        const SizedBox(width: 6),
        Text('= $desc',
            style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
      ]),
    );
  }

  Widget _buildPassageImageSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.photo_library_rounded, color: Colors.indigo.shade600, size: 18),
        const SizedBox(width: 8),
        Text('รูปภาพ Passage', style: TextStyle(fontWeight: FontWeight.bold,
            fontSize: 13, color: Colors.indigo.shade700)),
        const Spacer(),
        if (_ctrl.loadingPassageImages)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _ctrl.passageImages.isEmpty ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _ctrl.passageImages.isEmpty ? 'ยังไม่มีรูป' : '${_ctrl.passageImages.length} รูป',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: _ctrl.passageImages.isEmpty
                      ? Colors.orange.shade700 : Colors.green.shade700),
            ),
          ),
      ]),
      const SizedBox(height: 10),

      if (_ctrl.passageImages.isNotEmpty) ...[
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.72),
          itemCount: _ctrl.passageImages.length,
          itemBuilder: (_, i) => _passageImageTile(_ctrl.passageImages[i], i),
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _ctrl.isGeneratingAI ? null
                : () => _ctrl.aiScanImages(_ctrl.passageImages),
            icon: _ctrl.isGeneratingAI
                ? const SizedBox(width: 15, height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple))
                : const Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
            label: Text(_ctrl.isGeneratingAI
                ? 'กำลังสแกน ${_ctrl.passageImages.length} รูป...'
                : '✨ AI Scan ทุกรูป (${_ctrl.passageImages.length}) → Transcript',
                style: const TextStyle(color: Colors.purple, fontSize: 12)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.purple),
                padding: const EdgeInsets.symmetric(vertical: 10)),
          ),
        ),
        const SizedBox(height: 8),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200)),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('ยังไม่มีรูป — กดปุ่มด้านล่างเพื่อเพิ่ม',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
          ]),
        ),
        const SizedBox(height: 8),
      ],

      // ── 2 ปุ่มเพิ่มรูป ──────────────────────────────────────────────────────
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _ctrl.isLoading ? null : _ctrl.uploadPassageImages,
            icon: const Icon(Icons.cloud_upload_rounded, size: 17),
            label: const Text('อัปโหลดรูปใหม่', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _ctrl.isLoading ? null : _browsePassageImages,
            icon: const Icon(Icons.photo_library_rounded, size: 17),
            label: const Text('จาก Storage', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.indigo.shade700,
                side: BorderSide(color: Colors.indigo.shade400),
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
      ]),
    ]);
  }

  Widget _passageImageTile(String url, int i) {
    return Stack(children: [
      GestureDetector(
        onTap: () => _showFullImage(url),
        child: ClipRRect(borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.indigo.shade100),
                borderRadius: BorderRadius.circular(8)),
            child: Image.network(url, width: double.infinity, height: double.infinity, fit: BoxFit.cover,
              loadingBuilder: (_, child, p) => p == null ? child
                  : Container(color: Colors.grey.shade100,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorBuilder: (_, __, ___) => Container(color: Colors.red.shade50,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.broken_image, color: Colors.red.shade300, size: 24),
                  Text('โหลดไม่ได้', style: TextStyle(fontSize: 9, color: Colors.red.shade300)),
                ])),
            ),
          )),
      ),
      Positioned(top: 4, left: 4, child: _dot('${i + 1}', Colors.indigo.shade700)),
      Positioned(top: 4, right: 4, child: GestureDetector(
        onTap: () => _ctrl.removePassageImage(i),
        child: _dot('✕', Colors.red.shade700),
      )),
      Positioned(bottom: 4, left: 4, child: GestureDetector(
        onTap: _ctrl.isGeneratingAI ? null : () => _ctrl.aiScanImages([url]),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: Colors.purple.shade700.withOpacity(0.85),
              borderRadius: BorderRadius.circular(5)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.document_scanner_rounded, size: 11, color: Colors.white),
            SizedBox(width: 3),
            Text('Scan', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
        ),
      )),
    ]);
  }

  Widget _dot(String text, Color color) => Container(
    width: 22, height: 22,
    decoration: BoxDecoration(color: color.withOpacity(0.85), shape: BoxShape.circle),
    child: Center(child: Text(text,
        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
  );

  void _showFullImage(String url) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(8),
      child: Stack(alignment: Alignment.topRight, children: [
        InteractiveViewer(minScale: 0.5, maxScale: 4.0,
          child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Image.network(url, fit: BoxFit.contain))),
        Padding(padding: const EdgeInsets.all(4),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 26),
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
          )),
      ]),
    ));
  }

  // ── Question + Answer ───────────────────────────────────────────────────────
  Widget _buildQuestionSection() {
    return Column(children: [
      _field(_ctrl.qTextCtrl, 'โจทย์ (Question Text)', maxLines: 3, required: false),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(child: _field(_ctrl.optACtrl, 'ตัวเลือก A', required: false)),
        const SizedBox(width: 10),
        Expanded(child: _field(_ctrl.optBCtrl, 'ตัวเลือก B', required: false)),
      ]),
      Row(children: [
        Expanded(child: _field(_ctrl.optCCtrl, 'ตัวเลือก C', required: false)),
        const SizedBox(width: 10),
        Expanded(child: _field(_ctrl.optDCtrl, 'ตัวเลือก D', required: false)),
      ]),
    ]);
  }

  Widget _buildAnswerSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('เฉลยที่ถูกต้อง:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 10),
      Center(
        child: SegmentedButton<String>(
          segments: ['A','B','C','D'].map((l) => ButtonSegment(
            value: l, label: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
          )).toList(),
          selected: {_ctrl.selectedCorrectAnswer},
          onSelectionChanged: (v) => setState(() => _ctrl.selectedCorrectAnswer = v.first),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: Text('คำอธิบายเฉลย',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Colors.grey.shade700))),
        TextButton.icon(
          onPressed: _ctrl.isGeneratingAI ? null : _ctrl.aiGenerateExplanation,
          icon: _ctrl.isGeneratingAI
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
          label: Text(_ctrl.isGeneratingAI ? 'กำลังคิด...' : 'AI สรุปเฉลย',
              style: const TextStyle(color: Colors.purple, fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 6),
      _field(_ctrl.explanationCtrl, 'คำอธิบายเหตุผล...', maxLines: 6, required: false),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text('หมวดหมู่ (Category)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: Colors.grey.shade700))),
        Text('AI ระบุให้อัตโนมัติ',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ]),
      const SizedBox(height: 6),
      _field(_ctrl.categoryCtrl, 'เช่น Tense, Vocabulary, Detail...', required: false),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6,
        children: ['Grammar','Vocabulary','Tense','Passive Voice','Preposition',
            'Conjunction','Detail','Main Idea','Inference','Graphic Content'] //แก้ให้ดึงจาก db จริง
            .map((s) => GestureDetector(
              onTap: () => setState(() => _ctrl.categoryCtrl.text = s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _ctrl.categoryCtrl.text == s
                      ? Colors.teal.shade700 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: _ctrl.categoryCtrl.text == s
                        ? Colors.white : Colors.teal.shade700)),
              ),
            )).toList(),
      ),
    ]);
  }

  // ── Storage modals ──────────────────────────────────────────────────────────
  Future<void> _browseStorage(String type) async {
    if (_ctrl.testIdCtrl.text.isEmpty) { _showSnack('กรุณาระบุ Test ID ก่อน'); return; }
    _ctrl.isLoading = true; _ctrl.loadingMessage = 'โหลดไฟล์จาก Storage...';
    setState(() {});
    final found = await _ctrl.browseStorageFiles(type);
    _ctrl.isLoading = false; setState(() {});
    if (found.isEmpty) { _showSnack('ไม่พบไฟล์ใน Storage — ลองอัปโหลดก่อน'); return; }
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _StoragePickerSheet(
        files: found, type: type, supabase: _supabase,
        onSelected: (url) { if (type == 'audio') _ctrl.setAudioUrl(url); else _ctrl.setImageUrl(url); },
        onUpload: () => _ctrl.uploadFile(type),
      ),
    );
  }

  Future<void> _browsePassageImages() async {
    if (_ctrl.testIdCtrl.text.isEmpty) { _showSnack('กรุณาระบุ Test ID ก่อน'); return; }
    _ctrl.isLoading = true; _ctrl.loadingMessage = 'โหลดรูปจาก Storage...';
    setState(() {});
    final found = await _ctrl.browseStorageFiles('image');
    _ctrl.isLoading = false; setState(() {});
    if (found.isEmpty) { _showSnack('ไม่พบรูปใน Storage'); return; }
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _MultiImagePickerSheet(
        files: found, supabase: _supabase,
        onSelected: (urls) => _ctrl.addPassageImageUrls(urls),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _toggleBtn(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? Colors.purple.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? Colors.purple.shade700 : Colors.grey.shade300, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: active ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
              color: active ? Colors.white : Colors.grey.shade700)),
        ]),
      ),
    );
  }

  Widget _groupChip(String label, String? value) {
    final sel = _ctrl.selectedPassageGroup == value;
    return GestureDetector(
      onTap: () => _ctrl.selectGroup(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Colors.purple.shade700 : Colors.purple.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: sel ? Colors.white : Colors.purple.shade700)),
      ),
    );
  }

  Widget _card(String title, Widget content) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.bold,
              color: Colors.blue.shade800, fontSize: 14))),
        const Divider(height: 16),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: content),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {
    bool isNumber = false, int maxLines = 1, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl, maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.multiline,
        decoration: _deco(label),
        validator: required ? (v) => (v == null || v.isEmpty) ? 'กรุณากรอก $label' : null : null,
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label, filled: true, fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
    labelStyle: const TextStyle(fontSize: 13),
    alignLabelWithHint: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _AudioTimingSection — Audio Player พร้อมปุ่ม Set Start / Set End
// ─────────────────────────────────────────────────────────────────────────────

class _AudioTimingSection extends StatefulWidget {
  final String audioUrl;
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;

  const _AudioTimingSection({
    required this.audioUrl,
    required this.startCtrl,
    required this.endCtrl,
  });

  @override
  State<_AudioTimingSection> createState() => _AudioTimingSectionState();
}

class _AudioTimingSectionState extends State<_AudioTimingSection> {
  html.AudioElement? _audio;
  bool _isPlaying = false;
  double _currentSec = 0;
  double _totalSec   = 0;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.audioUrl.isNotEmpty) _initAudio(widget.audioUrl);
  }

  @override
  void didUpdateWidget(_AudioTimingSection old) {
    super.didUpdateWidget(old);
    if (old.audioUrl != widget.audioUrl && widget.audioUrl.isNotEmpty) {
      _audio?.pause();
      _audio = null;
      _isPlaying = false; _currentSec = 0; _totalSec = 0; _isLoaded = false;
      _initAudio(widget.audioUrl);
    }
  }

  void _initAudio(String url) {
    _audio = html.AudioElement(url)..preload = 'metadata';

    _audio!.onLoadedMetadata.listen((_) {
      if (mounted) {
        setState(() {
          _totalSec = _audio!.duration.toDouble();
          _isLoaded = true;
        });
      }
    });

    _audio!.onTimeUpdate.listen((_) {
      if (mounted) setState(() => _currentSec = _audio!.currentTime.toDouble());
    });

    _audio!.onEnded.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _audio?.pause();
    _audio = null;
    super.dispose();
  }

  void _togglePlay() {
    if (_audio == null) return;
    if (_isPlaying) {
      _audio!.pause();
    } else {
      final start = int.tryParse(widget.startCtrl.text) ?? 0;
      final end   = int.tryParse(widget.endCtrl.text) ?? 0;
      // ถ้ามีกำหนด start/end และ position ปัจจุบันอยู่นอก range → กระโดดไป start
      if (start > 0 && end > start) {
        if (_currentSec < start || _currentSec >= end) {
          _audio!.currentTime = start.toDouble();
        }
      }
      _audio!.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _seek(double sec) {
    _audio?.currentTime = sec;
    setState(() => _currentSec = sec);
  }

  void _setStart() {
    final sec = _currentSec.floor();
    widget.startCtrl.text = '$sec';
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ตั้งเวลาเริ่ม: ${_fmt(sec.toDouble())} (${sec}s)'),
          duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  void _setEnd() {
    final sec = _currentSec.ceil();
    widget.endCtrl.text = '$sec';
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ตั้งเวลาจบ: ${_fmt(sec.toDouble())} (${sec}s)'),
          duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
    );
  }

  String _fmt(double sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final startSec = int.tryParse(widget.startCtrl.text) ?? 0;
    final endSec   = int.tryParse(widget.endCtrl.text) ?? 0;
    final hasRange = endSec > startSec && startSec >= 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── 📌 Info Box ──────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text('วิธีกำหนดช่วงเสียงของแต่ละข้อ',
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 12, color: Colors.blue.shade800)),
          ]),
          const SizedBox(height: 8),
          _infoRow('1', '▶ กดเล่นเสียง แล้วฟังหาจุดที่โจทย์ข้อนี้เริ่มต้น'),
          _infoRow('2', 'กด  🔵 SET START  ทันทีที่ได้ยินเสียงของข้อนี้'),
          _infoRow('3', 'ฟังต่อจนจบ แล้วกด  🔴 SET END  เมื่อข้อนี้จบ'),
          _infoRow('4', 'ค่าที่ได้จะบันทึกเป็น "วินาที" ลงในฐานข้อมูลโดยอัตโนมัติ'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200)),
            child: Text(
              '⚠️ Part 1 ใช้ไฟล์เสียงรวม (Part1.mp3) — แต่ละข้อมีช่วงเวลาต่างกัน\n'
              'ตัวอย่าง: ข้อ 1 = 103–128s, ข้อ 2 = 129–160s, ข้อ 3 = 161–186s',
              style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900, height: 1.5),
            ),
          ),
        ]),
      ),

      if (widget.audioUrl.isEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            Icon(Icons.music_off_rounded, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 10),
            Text('เพิ่มไฟล์เสียงก่อน จึงจะใช้ Player ได้',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        )
      else ...[

        // ── Player Bar ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(children: [

            // Progress slider
            Row(children: [
              Text(_fmt(_currentSec),
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.orange.shade600,
                    inactiveTrackColor: Colors.orange.shade200,
                    thumbColor: Colors.orange.shade700,
                    overlayColor: Colors.orange.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _totalSec > 0
                        ? _currentSec.clamp(0, _totalSec) : 0,
                    min: 0,
                    max: _totalSec > 0 ? _totalSec : 1,
                    onChanged: _totalSec > 0 ? (v) => _seek(v) : null,
                  ),
                ),
              ),
              Text(_fmt(_totalSec),
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold)),
            ]),

            // Play button + range indicator
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // -15s
              IconButton(
                onPressed: _isLoaded ? () => _seek((_currentSec - 15).clamp(0, _totalSec)) : null,
                icon:const Icon(Icons.replay_10_rounded),
                color: Colors.orange.shade700,
                iconSize: 26,
                tooltip: 'ย้อนกลับ 10 วินาที',
              ),
              // Play/Pause
              Container(
                decoration: BoxDecoration(
                  color: _isLoaded ? Colors.orange.shade700 : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _isLoaded ? _togglePlay : null,
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded ),
                  color: Colors.white,
                  iconSize: 30,
                  tooltip: _isPlaying ? 'หยุด' : 'เล่น',
                ),
              ),
              // +15s
              IconButton(
                onPressed: _isLoaded ? () => _seek((_currentSec + 10).clamp(0, _totalSec)) : null,
                icon: const Icon(Icons.forward_10_rounded),
                color: Colors.orange.shade700,
                iconSize: 26,
                tooltip: 'ข้ามไป 10 วินาที',
              ),
              if (!_isLoaded) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 6),
                Text('กำลังโหลด...', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ],
            ]),

            // Range display
            if (hasRange) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '🎯 ช่วงที่กำหนด: ${_fmt(startSec.toDouble())} → ${_fmt(endSec.toDouble())} '
                  '($startSec s – $endSec s)',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade800,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 10),

        // ── Set Start / Set End ──────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _isLoaded ? _setStart : null,
              icon: const Icon(Icons.flag_rounded, size: 17),
              label: Text(
                startSec > 0
                    ? '🔵 START  ${_fmt(startSec.toDouble())} (${startSec}s)'
                    : '🔵 SET START',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _isLoaded ? _setEnd : null,
              icon: const Icon(Icons.sports_score_rounded, size: 17),
              label: Text(
                endSec > 0
                    ? '🔴 END  ${_fmt(endSec.toDouble())} (${endSec}s)'
                    : '🔴 SET END',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ]),

        // ── Manual input fallback ────────────────────────────────────────────
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(
            controller: widget.startCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'เริ่ม (วินาที)',
              labelStyle: const TextStyle(fontSize: 12),
              prefixIcon: Icon(Icons.timer_outlined, size: 16, color: Colors.blue.shade600),
              filled: true, fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(
            controller: widget.endCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'จบ (วินาที)',
              labelStyle: const TextStyle(fontSize: 12),
              prefixIcon: Icon(Icons.timer_off_outlined, size: 16, color: Colors.red.shade600),
              filled: true, fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
            onChanged: (_) => setState(() {}),
          )),
        ]),
      ],
    ]);
  }

  Widget _infoRow(String num, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 18, height: 18, margin: const EdgeInsets.only(right: 8, top: 1),
        decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle),
        child: Center(child: Text(num,
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
      ),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.5))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _StoragePickerSheet — single file select
// ─────────────────────────────────────────────────────────────────────────────
class _StoragePickerSheet extends StatelessWidget {
  final Map<String, String> files;
  final String type;
  final SupabaseClient supabase;
  final void Function(String url) onSelected;
  final VoidCallback onUpload;
  const _StoragePickerSheet({required this.files, required this.type,
      required this.supabase, required this.onSelected, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final isAudio = type == 'audio';
    final bucket  = supabase.storage.from('exam-assets');
    return Container(
      height: MediaQuery.of(context).size.height * 0.60,
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            Icon(isAudio ? Icons.library_music_rounded : Icons.photo_library_rounded,
                color: Colors.blue.shade700),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('เลือกไฟล์${isAudio ? 'เสียง' : 'รูปภาพ'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${files.length} ไฟล์',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            TextButton.icon(
              onPressed: () { Navigator.pop(context); onUpload(); },
              icon: const Icon(Icons.upload_rounded, size: 15),
              label: const Text('อัปโหลดใหม่', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),
        Expanded(child: ListView.builder(
          itemCount: files.length,
          itemBuilder: (_, i) {
            final e = files.entries.elementAt(i);
            final name = e.key; final path = e.value;
            final url  = bucket.getPublicUrl(path);
            final folder = path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : path;
            return ListTile(
              leading: isAudio
                  ? Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.music_note_rounded, color: Colors.orange.shade600, size: 22))
                  : ClipRRect(borderRadius: BorderRadius.circular(6),
                      child: Image.network(url, width: 42, height: 42, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 42, height: 42,
                            color: Colors.grey.shade100,
                            child: Icon(Icons.image, color: Colors.grey.shade400)))),
              title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(folder, style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  overflow: TextOverflow.ellipsis),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero),
                onPressed: () { onSelected(url); Navigator.pop(context); },
                child: const Text('เลือก', style: TextStyle(fontSize: 12)),
              ),
            );
          },
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MultiImagePickerSheet — multi select for passage group
// ─────────────────────────────────────────────────────────────────────────────
class _MultiImagePickerSheet extends StatefulWidget {
  final Map<String, String> files;
  final SupabaseClient supabase;
  final void Function(List<String> urls) onSelected;
  const _MultiImagePickerSheet({required this.files, required this.supabase, required this.onSelected});
  @override State<_MultiImagePickerSheet> createState() => _MultiImagePickerSheetState();
}

class _MultiImagePickerSheetState extends State<_MultiImagePickerSheet> {
  final _sel = <String>{};

  @override
  Widget build(BuildContext context) {
    final bucket = widget.supabase.storage.from('exam-assets');
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            const Icon(Icons.photo_library_rounded, color: Colors.indigo),
            const SizedBox(width: 8),
            const Expanded(child: Text('เลือกรูปภาพจาก Storage',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            FilledButton.icon(
              onPressed: _sel.isEmpty ? null : () {
                widget.onSelected(_sel.map((p) => bucket.getPublicUrl(p)).toList());
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check, size: 16),
              label: Text('เพิ่ม ${_sel.length} รูป'),
            ),
          ]),
        ),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
          itemCount: widget.files.length,
          itemBuilder: (_, i) {
            final e = widget.files.entries.elementAt(i);
            final name = e.key; final path = e.value;
            final url  = bucket.getPublicUrl(path);
            final sel  = _sel.contains(path);
            return GestureDetector(
              onTap: () => setState(() { if (sel) _sel.remove(path); else _sel.add(path); }),
              child: Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: sel ? Colors.indigo.shade500 : Colors.grey.shade200,
                            width: sel ? 2.5 : 1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Image.network(url, width: double.infinity, height: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade100,
                          child: Icon(Icons.image, color: Colors.grey.shade400))),
                  )),
                if (sel) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: Container(color: Colors.indigo.withOpacity(0.25))),
                  Positioned(top: 4, right: 4, child: Container(width: 22, height: 22,
                      decoration: BoxDecoration(color: Colors.indigo.shade700, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 14, color: Colors.white))),
                ],
                Positioned(bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45),
                        borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
                    child: Text(name, style: const TextStyle(fontSize: 9, color: Colors.white),
                        overflow: TextOverflow.ellipsis),
                  )),
              ]),
            );
          },
        )),
      ]),
    );
  }
}
