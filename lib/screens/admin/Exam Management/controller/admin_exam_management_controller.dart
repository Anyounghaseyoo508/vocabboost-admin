import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminExamManagementController
//
// รับผิดชอบ: navigation state, Supabase calls, business logic ทั้งหมด
// ไม่รู้จัก BuildContext หรือ Widget — ส่งผลลัพธ์ผ่าน callback และ notifyListeners
// ─────────────────────────────────────────────────────────────────────────────
class AdminExamManagementController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // ── Navigation State ────────────────────────────────────────────────────────
  int _currentLevel = 0; // 0=List, 1=Part, 2=Questions
  int get currentLevel => _currentLevel;

  int? _selectedTestId;
  int? get selectedTestId => _selectedTestId;

  String? _selectedTestTitle;
  String? get selectedTestTitle => _selectedTestTitle;

  int? _selectedPart;
  int? get selectedPart => _selectedPart;

  // ── Callback → Screen ใช้แสดง SnackBar ────────────────────────────────────
  void Function(String msg)? onSnack;

  // ── Navigation ──────────────────────────────────────────────────────────────
  /// เข้าหน้า Part selector
  void selectTestSet(int testId, String title) {
    _selectedTestId    = testId;
    _selectedTestTitle = title;
    _currentLevel      = 1;
    notifyListeners();
  }

  /// เข้าหน้ารายการข้อสอบของ Part
  void selectPart(int part) {
    _selectedPart = part;
    _currentLevel = 2;
    notifyListeners();
  }

  /// ย้อนกลับ 1 ระดับ (Back button / PopScope)
  bool goBack() {
    if (_currentLevel == 0) return false; // ให้ pop ออกจาก screen
    _currentLevel--;
    notifyListeners();
    return true;
  }

  // ── Streams (ให้ Screen subscribe โดยตรง) ──────────────────────────────────
  Stream<List<Map<String, dynamic>>> get examSetsStream =>
      _supabase.from('exam_sets').stream(primaryKey: ['test_id']).order('test_id');

  Stream<List<Map<String, dynamic>>> get practiceTestStream =>
      _supabase.from('practice_test').stream(primaryKey: ['id']).order('question_no');

  // ── Count future สำหรับแต่ละ Test Set ─────────────────────────────────────
  Future<int> questionCount(int testId) => _supabase
      .from('practice_test')
      .select('id')
      .eq('test_id', testId)
      .then((r) => (r as List).length);

  // ── Test Set Actions ────────────────────────────────────────────────────────
  Future<void> createTestSet(String title) async {
    if (title.isEmpty) return;
    final existing = await _supabase
        .from('exam_sets')
        .select('test_id')
        .order('test_id', ascending: false)
        .limit(1)
        .maybeSingle();
    final nextTestId = (existing?['test_id'] as int? ?? 0) + 1;
    await _supabase.from('exam_sets').insert({
      'test_id':      nextTestId,
      'title':        title,
      'is_published': false,
    });
    onSnack?.call('✅ สร้างชุดข้อสอบ Test $nextTestId — $title สำเร็จ');
  }

  Future<void> renameTestSet(int testId, String newTitle) async {
    if (newTitle.isEmpty) return;
    await _supabase
        .from('exam_sets')
        .update({'title': newTitle})
        .eq('test_id', testId);
  }

  Future<void> togglePublish(int testId, bool currentPublished) async {
    await _supabase
        .from('exam_sets')
        .update({'is_published': !currentPublished})
        .eq('test_id', testId);
    onSnack?.call(currentPublished ? '🔒 ซ่อนชุดข้อสอบแล้ว' : '✅ เผยแพร่ชุดข้อสอบแล้ว');
  }

  Future<void> deleteTestSet(int testId) async {
    await _supabase.from('practice_test').delete().eq('test_id', testId);
    await _supabase.from('exam_sets').delete().eq('test_id', testId);
  }

  // ── Question Actions ────────────────────────────────────────────────────────
  Future<void> deleteQuestion(dynamic id) async {
    await _supabase.from('practice_test').delete().eq('id', id);
  }

  // ── Grouping Logic ──────────────────────────────────────────────────────────
  /// จัดกลุ่มข้อสอบตาม passage_group_id
  List<Map<String, dynamic>> groupByPassage(List<Map<String, dynamic>> docs) {
    final result = <Map<String, dynamic>>[];
    final used   = <String>{};
    for (final item in docs) {
      final gId = item['passage_group_id']?.toString().trim() ?? '';
      if (gId.isEmpty) {
        result.add({'isGroup': false, 'item': item});
      } else if (!used.contains(gId)) {
        used.add(gId);
        result.add({
          'isGroup': true,
          'groupId': gId,
          'items': docs.where((e) => e['passage_group_id']?.toString().trim() == gId).toList(),
        });
      }
    }
    return result;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String getAppBarTitle() {
    if (_currentLevel == 0) return 'คลังข้อสอบ';
    if (_currentLevel == 1) return _selectedTestTitle ?? 'Test #$_selectedTestId';
    return 'Part $_selectedPart · ${partName(_selectedPart!)}';
  }

  String getAppBarSubtitle() {
    if (_currentLevel == 1) return 'Test ID: $_selectedTestId · เลือก Part';
    return 'Test #$_selectedTestId · ${_selectedTestTitle ?? ''}';
  }

  String partName(int p) {
    const names = [
      'Photographs', 'Questions & Responses', 'Conversations', 'Short Talks',
      'Incomplete Sentences', 'Text Completion', 'Reading Comprehension',
    ];
    return names[p - 1];
  }

  /// กรองเฉพาะข้อสอบของ test และ part ที่เลือก แล้ว sort ตาม question_no
  List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> all) {
    return all
        .where((e) => e['test_id'] == _selectedTestId && e['part'] == _selectedPart)
        .toList()
      ..sort((a, b) => (a['question_no'] as int).compareTo(b['question_no'] as int));
  }
}
