import 'dart:io';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Unified item model ────────────────────────────────────────────────────────
class _ContentItem {
  final String       id;
  final String       source;     // 'sheet' | 'resource'
  final String       title;
  final String       description;
  final String       detail;     // resource only (long description)
  final String       type;       // 'sheet' | 'youtube' | 'article' | 'website' | 'other'
  final String       category;   // sheet only
  final String       url;        // resource only
  final String       pdfUrl;     // sheet only
  final List<String> imageUrls;
  final bool         isPinned;
  final DateTime     createdAt;

  const _ContentItem({required this.id, required this.source, required this.title,
    required this.description, required this.detail, required this.type, required this.category,
    required this.url, required this.pdfUrl, required this.imageUrls,
    required this.isPinned, required this.createdAt});

  static List<String> _urls(dynamic raw) =>
      raw is List ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : [];

  factory _ContentItem.fromSheet(Map<String, dynamic> m) => _ContentItem(
    id: m['id'].toString(), source: 'sheet', title: m['title'] ?? '',
    description: m['description'] ?? '', detail: '', type: 'sheet', category: m['category'] ?? '',
    url: '', pdfUrl: m['pdf_url'] ?? '', imageUrls: _urls(m['image_urls']),
    isPinned: m['is_pinned'] == true,
    createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
  );

  factory _ContentItem.fromResource(Map<String, dynamic> m) => _ContentItem(
    id: m['id'].toString(), source: 'resource', title: m['title'] ?? '',
    description: m['description'] ?? '', detail: m['detail'] ?? '', type: m['type'] ?? 'other', category: '',
    url: m['url'] ?? '', pdfUrl: '', imageUrls: _urls(m['image_urls']),
    isPinned: m['is_pinned'] == true,
    createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class AdminSheetManagementScreen extends StatefulWidget {
  const AdminSheetManagementScreen({super.key});
  @override
  State<AdminSheetManagementScreen> createState() => _AdminSheetManagementScreenState();
}

class _AdminSheetManagementScreenState extends State<AdminSheetManagementScreen> {
  final _supabase = Supabase.instance.client;

  static const _typeIcon = <String, IconData>{
    'youtube': Icons.play_circle_fill_rounded, 'article': Icons.article_rounded,
    'website': Icons.language_rounded,         'other':   Icons.link_rounded,
    'sheet':   Icons.picture_as_pdf_rounded,
  };
  static const _typeColor = <String, Color>{
    'youtube': Color(0xFFE53935), 'article': Color(0xFF1A56DB),
    'website': Color(0xFF0891B2), 'other':   Color(0xFF7C3AED),
    'sheet':   Color(0xFFE53935),
  };
  static const _typeLabel = <String, String>{
    'youtube': 'YouTube', 'article': 'บทความ',
    'website': 'เว็บไซต์', 'other':  'อื่นๆ', 'sheet': 'PDF',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("จัดการเนื้อหา"),
        backgroundColor: Colors.orange, foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.orange.withOpacity(0.08),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 15, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text(
              "กด ⭐ เพื่อโชว์บน Dashboard (รวมทุกประเภท สูงสุด 6 รายการ)",
              style: TextStyle(fontSize: 12, color: Colors.orange),
            )),
          ]),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('sheets').stream(primaryKey: ['id']),
            builder: (context, sheetsSnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase.from('learning_resources').stream(primaryKey: ['id']),
                builder: (context, resourcesSnap) {
                  if (!sheetsSnap.hasData || !resourcesSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = [
                    ...sheetsSnap.data!.map(_ContentItem.fromSheet),
                    ...resourcesSnap.data!.map(_ContentItem.fromResource),
                  ]..sort((a, b) {
                    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
                    return b.createdAt.compareTo(a.createdAt);
                  });

                  if (all.isEmpty) return const Center(child: Text("ยังไม่มีเนื้อหาในระบบ"));

                  final pinnedCount = all.where((e) => e.isPinned).length;

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100, top: 4),
                    itemCount: all.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final item  = all[i];
                      final icon  = _typeIcon[item.type]  ?? Icons.link_rounded;
                      final color = _typeColor[item.type] ?? const Color(0xFF7C3AED);
                      final label = _typeLabel[item.type] ?? 'อื่นๆ';

                      return ListTile(
                        leading: GestureDetector(
                          onTap: () => _togglePin(context, item, pinnedCount),
                          child: Tooltip(
                            message: item.isPinned ? 'ซ่อนจาก Dashboard' : 'โชว์บน Dashboard',
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: item.isPinned ? Colors.orange.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.isPinned ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: item.isPinned ? Colors.orange : Colors.grey, size: 22),
                            ),
                          ),
                        ),
                        title: Row(children: [
                          Icon(icon, color: color, size: 14),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: item.isPinned ? FontWeight.w700 : FontWeight.w500))),
                        ]),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (item.description.isNotEmpty)
                              Text(item.description,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.4)),
                            const SizedBox(height: 3),
                            Row(children: [
                              if (item.isPinned) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                  child: const Text("Dashboard", style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (item.imageUrls.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFE0F7FA), borderRadius: BorderRadius.circular(8)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.photo_library_rounded, size: 9, color: Color(0xFF0891B2)),
                                    const SizedBox(width: 3),
                                    Text('${item.imageUrls.length} รูป', style: const TextStyle(fontSize: 9, color: Color(0xFF0891B2), fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(child: Text(
                                item.source == 'sheet' ? item.category : item.url,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              )),
                            ]),
                          ]),
                        ),
                        isThreeLine: true,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'แก้ไข', icon: const Icon(Icons.edit_rounded, color: Colors.orange, size: 20),
                            onPressed: () => item.source == 'sheet'
                                ? _showSheetDialog(context: context, title: "แก้ไขชีทสรุป",
                                    initialData: {'id': item.id, 'title': item.title, 'category': item.category,
                                      'description': item.description, 'pdf_url': item.pdfUrl.isNotEmpty ? item.pdfUrl : null, 'image_urls': item.imageUrls},
                                    onSave: (d) async => await _supabase.from('sheets').update(d).eq('id', item.id))
                                : _showResourceDialog(context: context, title: "แก้ไขแหล่งเรียนรู้",
                                    initialData: {'id': item.id, 'title': item.title, 'type': item.type,
                                      'url': item.url, 'description': item.description, 'detail': item.detail, 'image_urls': item.imageUrls},
                                    onSave: (d) async => await _supabase.from('learning_resources').update(d).eq('id', item.id)),
                          ),
                          IconButton(
                            tooltip: 'ลบ', icon: const Icon(Icons.delete_rounded, color: Colors.grey, size: 20),
                            onPressed: () => _confirmDelete(context, item),
                          ),
                        ]),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ]),
      floatingActionButton: _AddFab(
        onAddSheet: () => _showSheetDialog(
          context: context, title: "เพิ่มชีทสรุป",
          onSave: (d) async => await _supabase.from('sheets').insert(d)),
        onAddResource: () => _showResourceDialog(
          context: context, title: "เพิ่มแหล่งเรียนรู้",
          onSave: (d) async => await _supabase.from('learning_resources').insert(d)),
      ),
    );
  }

  // ── Toggle pin ────────────────────────────────────────────────────────────
  Future<void> _togglePin(BuildContext context, _ContentItem item, int pinnedCount) async {
    if (!item.isPinned && pinnedCount >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("โชว์ได้สูงสุด 6 รายการ (รวมทุกประเภท) กรุณายกเลิกรายการอื่นก่อน"),
          backgroundColor: Colors.deepOrange));
      return;
    }
    final table = item.source == 'sheet' ? 'sheets' : 'learning_resources';
    try {
      await _supabase.from(table).update({'is_pinned': !item.isPinned}).eq('id', item.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!item.isPinned ? "📌 เพิ่มบน Dashboard แล้ว" : "ซ่อนจาก Dashboard แล้ว"),
          duration: const Duration(seconds: 1)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ผิดพลาด: $e")));
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(BuildContext context, _ContentItem item) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text("ยืนยันการลบ"),
      content: Text("ต้องการลบ \"${item.title}\" ใช่หรือไม่?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ยกเลิก")),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("ลบ", style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      final table = item.source == 'sheet' ? 'sheets' : 'learning_resources';
      try {
        await _supabase.from(table).delete().eq('id', item.id);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ลบข้อมูลสำเร็จ")));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ลบไม่สำเร็จ: $e")));
      }
    }
  }

  // ── Sheet Dialog ──────────────────────────────────────────────────────────
  Future<void> _showSheetDialog({required BuildContext context, required String title,
      Map<String, dynamic>? initialData, required Future<void> Function(Map<String, dynamic>) onSave}) async {
    final titleCtrl    = TextEditingController(text: initialData?['title'] ?? '');
    final categoryCtrl = TextEditingController(text: initialData?['category'] ?? '');
    final descCtrl     = TextEditingController(text: initialData?['description'] ?? '');
    String? pickedFileName = initialData?['pdf_url'] != null ? '(ไฟล์เดิม)' : null;
    Uint8List? pickedBytes;
    final existingPdfUrl = initialData?['pdf_url'] as String?;
    final rawEx = initialData?['image_urls'];
    List<String> existingUrls = rawEx is List ? rawEx.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : [];
    List<_PickedImage> newImages = [];
    bool isUploading = false, isSaving = false;
    final picker = ImagePicker();

    await showDialog(context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final totalImg = existingUrls.length + newImages.length;
        final hasPdf   = pickedBytes != null || existingPdfUrl != null;
        return AlertDialog(
          title: Row(children: [
            Icon(initialData == null ? Icons.upload_file_rounded : Icons.edit_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8), Text(title),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: SizedBox(width: double.maxFinite,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl("ชื่อเรื่อง *"), const SizedBox(height: 6),
              TextField(controller: titleCtrl, decoration: _deco("ชื่อชีทสรุป"), textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              _lbl("หมวดหมู่"), const SizedBox(height: 6),
              TextField(controller: categoryCtrl, decoration: _deco("เช่น Grammar, Vocabulary"), textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              _lbl("คำอธิบายสั้น"), const SizedBox(height: 6),
              TextField(controller: descCtrl, decoration: _deco("สรุปเนื้อหาสั้นๆ"), maxLines: 2),
              const SizedBox(height: 14),
              _lbl(initialData == null ? "ไฟล์ PDF *" : "ไฟล์ PDF (เว้นว่างถ้าไม่เปลี่ยน)"),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: hasPdf ? Colors.green : Colors.orange.shade300),
                    backgroundColor: hasPdf ? Colors.green.withOpacity(0.05) : Colors.orange.withOpacity(0.04),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: Icon(hasPdf ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
                      color: hasPdf ? Colors.green : Colors.orange, size: 20),
                  label: Row(children: [
                    Expanded(child: Text(
                      pickedBytes != null ? (pickedFileName ?? 'ไฟล์ที่เลือก')
                          : existingPdfUrl != null ? '(มีไฟล์เดิม — คลิกเพื่อเปลี่ยน)' : 'คลิกเพื่อเลือกไฟล์ PDF',
                      style: TextStyle(fontSize: 13, color: hasPdf ? Colors.green.shade700 : Colors.orange),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    )),
                    if (pickedBytes != null)
                      InkWell(onTap: () => set(() { pickedBytes = null; pickedFileName = existingPdfUrl != null ? '(ไฟล์เดิม)' : null; }),
                        child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey)),
                  ]),
                  onPressed: isSaving ? null : () async {
                    try {
                      if (kIsWeb) {
                        final input = html.FileUploadInputElement()..accept = 'application/pdf'..click();
                        await input.onChange.first;
                        if (input.files!.isEmpty) return;
                        final file = input.files!.first;
                        if (!file.name.toLowerCase().endsWith('.pdf')) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("กรุณาเลือกไฟล์ PDF เท่านั้น"), backgroundColor: Colors.deepOrange));
                          return;
                        }
                        final reader = html.FileReader()..readAsArrayBuffer(file);
                        await reader.onLoad.first;
                        set(() { pickedFileName = file.name; pickedBytes = Uint8List.fromList(reader.result as List<int>); });
                      } else {
                        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true, allowMultiple: false);
                        if (result != null && result.files.isNotEmpty) {
                          final f = result.files.first;
                          final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
                          if (bytes != null) set(() { pickedFileName = f.name; pickedBytes = bytes; });
                        }
                      }
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("เลือกไฟล์ไม่ได้: $e")));
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              ..._imgSection(totalImg, existingUrls, newImages, isSaving, isUploading, picker, set),
            ])),
          ),
          actions: [
            TextButton(onPressed: (isSaving || isUploading) ? null : () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              icon: (isSaving || isUploading) ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: Text(isUploading ? "กำลังอัปโหลด..." : "บันทึก", style: const TextStyle(color: Colors.white)),
              onPressed: (isSaving || isUploading) ? null : () async {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("กรุณากรอกชื่อเรื่อง"))); return; }
                if (initialData == null && pickedBytes == null) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("กรุณาเลือกไฟล์ PDF"))); return; }
                set(() => isSaving = true);
                try {
                  String? pdfUrl = existingPdfUrl;
                  if (pickedBytes != null) {
                    final rawName  = (pickedFileName ?? 'sheet.pdf').replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
                    final fileName = rawName.replaceAll('.pdf', '_${DateTime.now().millisecondsSinceEpoch}.pdf');
                    await _supabase.storage.from('sheets').uploadBinary(fileName, pickedBytes!, fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true));
                    pdfUrl = _supabase.storage.from('sheets').getPublicUrl(fileName);
                  }
                  final finalUrls = await _uploadImgs(newImages, existingUrls, set);
                  await onSave({'title': t, 'category': categoryCtrl.text.trim(), 'description': descCtrl.text.trim(), 'pdf_url': pdfUrl, 'image_urls': finalUrls});
                  if (ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(initialData == null ? "เพิ่มชีทสรุปสำเร็จ" : "แก้ไขข้อมูลสำเร็จ"))); }
                } catch (e) {
                  set(() { isSaving = false; isUploading = false; });
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("ผิดพลาด: $e")));
                }
              },
            ),
          ],
        );
      }),
    );
  }

  // ── Resource Dialog ───────────────────────────────────────────────────────
  Future<void> _showResourceDialog({required BuildContext context, required String title,
      Map<String, dynamic>? initialData, required Future<void> Function(Map<String, dynamic>) onSave}) async {
    final titleCtrl  = TextEditingController(text: initialData?['title'] ?? '');
    final urlCtrl    = TextEditingController(text: initialData?['url'] ?? '');
    final descCtrl   = TextEditingController(text: initialData?['description'] ?? '');
    final detailCtrl = TextEditingController(text: initialData?['detail'] ?? '');
    String selectedType = initialData?['type'] ?? 'youtube';
    final rawEx = initialData?['image_urls'];
    List<String> existingUrls = rawEx is List ? rawEx.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : [];
    List<_PickedImage> newImages = [];
    bool isUploading = false, isSaving = false;
    final picker = ImagePicker();
    const typeMap = <String, (IconData, Color)>{
      'youtube': (Icons.play_circle_fill_rounded, Color(0xFFFF0000)),
      'article': (Icons.article_rounded,          Color(0xFF1A56DB)),
      'website': (Icons.language_rounded,         Color(0xFF0891B2)),
      'other':   (Icons.link_rounded,             Color(0xFF7C3AED)),
    };
    const typeLabel = <String, String>{'youtube': 'YouTube', 'article': 'บทความ', 'website': 'เว็บไซต์', 'other': 'อื่นๆ'};

    await showDialog(context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final totalCount = existingUrls.length + newImages.length;
        return AlertDialog(
          title: Row(children: [
            Icon(initialData == null ? Icons.add_link_rounded : Icons.edit_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8), Text(title),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          content: SizedBox(width: double.maxFinite,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl("ประเภท"), const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: typeMap.keys.map((t) {
                final selected = selectedType == t;
                final (icon, color) = typeMap[t]!;
                return ChoiceChip(
                  avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
                  label: Text(typeLabel[t] ?? t), selected: selected, selectedColor: color,
                  labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontSize: 12),
                  onSelected: (_) => set(() => selectedType = t),
                );
              }).toList()),
              const SizedBox(height: 14),
              _lbl("ชื่อเรื่อง *"), const SizedBox(height: 6),
              TextField(controller: titleCtrl, decoration: _deco("เช่น TOEIC Listening Tips"), textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              _lbl("URL / ลิงก์ *"), const SizedBox(height: 6),
              TextField(controller: urlCtrl, decoration: _deco("https://..."), keyboardType: TextInputType.url, textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              _lbl("คำอธิบายสั้น (แสดงบน card)"), const SizedBox(height: 6),
              TextField(controller: descCtrl, decoration: _deco("สรุปสั้นๆ 1-2 บรรทัด"), maxLines: 2),
              const SizedBox(height: 12),
              _lbl("รายละเอียด (แสดงหน้า detail)"), const SizedBox(height: 6),
              TextField(controller: detailCtrl, decoration: _deco("อธิบายเนื้อหาเพิ่มเติม..."), maxLines: 5, minLines: 3),
              const SizedBox(height: 14),
              ..._imgSection(totalCount, existingUrls, newImages, isSaving, isUploading, picker, set),
            ])),
          ),
          actions: [
            TextButton(onPressed: (isSaving || isUploading) ? null : () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              icon: (isSaving || isUploading) ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: Text(isUploading ? "กำลังอัปโหลดรูป..." : "บันทึก", style: const TextStyle(color: Colors.white)),
              onPressed: (isSaving || isUploading) ? null : () async {
                final t = titleCtrl.text.trim(); final u = urlCtrl.text.trim();
                if (t.isEmpty || u.isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("กรุณากรอกชื่อเรื่องและ URL"))); return; }
                set(() => isSaving = true);
                try {
                  final finalUrls = await _uploadImgs(newImages, existingUrls, set);
                  await onSave({'title': t, 'url': u, 'description': descCtrl.text.trim(), 'detail': detailCtrl.text.trim(), 'image_urls': finalUrls, 'type': selectedType});
                  if (ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(initialData == null ? "เพิ่มแหล่งเรียนรู้สำเร็จ" : "แก้ไขข้อมูลสำเร็จ"))); }
                } catch (e) {
                  set(() { isSaving = false; isUploading = false; });
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("ผิดพลาด: $e")));
                }
              },
            ),
          ],
        );
      }),
    );
  }

  // ── Shared image section ──────────────────────────────────────────────────
  List<Widget> _imgSection(int total, List<String> existing, List<_PickedImage> newImgs,
      bool saving, bool uploading, ImagePicker picker, StateSetter set) => [
    Row(children: [
      _lbl("รูปภาพ ($total รูป)"), const Spacer(),
      if (total > 0) Text("กด × เพื่อลบ", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ]),
    const SizedBox(height: 8),
    if (total > 0) GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: total,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemBuilder: (_, i) {
        final isEx = i < existing.length;
        return Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: isEx
                ? Image.network(existing[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_rounded, color: Colors.grey)))
                : Image.memory(newImgs[i - existing.length].bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          ),
          if (!isEx) Positioned(left: 4, top: 4, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(6)),
            child: const Text("ใหม่", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
          )),
          Positioned(right: 4, top: 4, child: GestureDetector(
            onTap: () => set(() { if (isEx) existing.removeAt(i); else newImgs.removeAt(i - existing.length); }),
            child: Container(width: 22, height: 22,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14)),
          )),
        ]);
      },
    ),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.orange.shade300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.orange, size: 18),
        label: Text(total == 0 ? "เลือกรูปภาพ" : "เพิ่มรูปภาพ", style: const TextStyle(color: Colors.orange, fontSize: 13)),
        onPressed: (saving || uploading) ? null : () async {
          final picked = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1200);
          if (picked.isNotEmpty) {
            final loaded = await Future.wait(picked.map((f) async {
              final bytes = await f.readAsBytes();
              final ext   = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'jpg';
              return _PickedImage(file: f, bytes: bytes, ext: ext);
            }));
            set(() => newImgs.addAll(loaded));
          }
        },
      ),
    ),
    const SizedBox(height: 8),
  ];

  // ── Upload images helper ──────────────────────────────────────────────────
  Future<List<String>> _uploadImgs(List<_PickedImage> newImgs, List<String> existing, StateSetter set) async {
    final uploaded = <String>[];
    for (int i = 0; i < newImgs.length; i++) {
      set(() {});
      final img      = newImgs[i];
      final ext      = img.ext;
      final rawName  = (img.file?.name ?? 'image.$ext').replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final baseName = rawName.contains('.') ? rawName.substring(0, rawName.lastIndexOf('.')) : rawName;
      final fileName = '${baseName}_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final mimeType = const {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp'}[ext] ?? 'image/jpeg';
      await _supabase.storage.from('resource-images').uploadBinary(fileName, img.bytes, fileOptions: FileOptions(contentType: mimeType, upsert: true));
      uploaded.add(_supabase.storage.from('resource-images').getPublicUrl(fileName));
    }
    return [...existing, ...uploaded];
  }

  static Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600));
  static InputDecoration _deco(String h) => InputDecoration(
    hintText: h, hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true,
  );
}

// ── Speed Dial FAB ────────────────────────────────────────────────────────────
class _AddFab extends StatefulWidget {
  final VoidCallback onAddSheet;
  final VoidCallback onAddResource;
  const _AddFab({required this.onAddSheet, required this.onAddResource});
  @override State<_AddFab> createState() => _AddFabState();
}

class _AddFabState extends State<_AddFab> with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() => setState(() { _open = !_open; _open ? _ctrl.forward() : _ctrl.reverse(); });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (_open) ...[
        FadeTransition(opacity: _anim, child: ScaleTransition(scale: _anim,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: const Text("เพิ่มชีทสรุป (PDF)", style: TextStyle(color: Colors.white, fontSize: 11))),
            const SizedBox(width: 8),
            FloatingActionButton.small(heroTag: 'fab_sheet', backgroundColor: const Color(0xFFE53935),
              onPressed: () { _toggle(); widget.onAddSheet(); },
              child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white)),
          ]),
        )),
        const SizedBox(height: 10),
        FadeTransition(opacity: _anim, child: ScaleTransition(scale: _anim,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: const Text("เพิ่มแหล่งเรียนรู้", style: TextStyle(color: Colors.white, fontSize: 11))),
            const SizedBox(width: 8),
            FloatingActionButton.small(heroTag: 'fab_resource', backgroundColor: const Color(0xFF1A56DB),
              onPressed: () { _toggle(); widget.onAddResource(); },
              child: const Icon(Icons.add_link_rounded, color: Colors.white)),
          ]),
        )),
        const SizedBox(height: 10),
      ],
      FloatingActionButton(heroTag: 'fab_main', backgroundColor: Colors.orange,
        onPressed: _toggle,
        child: AnimatedRotation(turns: _open ? 0.125 : 0, duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.add, color: Colors.white)),
      ),
    ]);
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
class _PickedImage {
  final dynamic   file;
  final Uint8List bytes;
  final String    ext;
  const _PickedImage({required this.file, required this.bytes, required this.ext});
}