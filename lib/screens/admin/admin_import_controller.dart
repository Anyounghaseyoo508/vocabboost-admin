import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class ImportResult {
  final int imported, duplicates, skipped, passagesInserted;
  final List<String> errors;
  final List<String> duplicateIds;
  const ImportResult({
    required this.imported,
    required this.duplicates,
    required this.skipped,
    required this.passagesInserted,
    required this.errors,
    required this.duplicateIds,
  });
}

class PreviewRow {
  final int rowNum;
  final int testId, part, questionNo;
  final String questionText;
  final String status; // 'new' | 'duplicate' | 'error'
  final String? errorMsg;
  final String? passageGroupId;
  final bool willInsertPassage;

  const PreviewRow({
    required this.rowNum,
    required this.testId,
    required this.part,
    required this.questionNo,
    required this.questionText,
    required this.status,
    this.errorMsg,
    this.passageGroupId,
    this.willInsertPassage = false,
  });
}

enum ImportStep { idle, validating, preview, importing, done }

// ─────────────────────────────────────────────────────────────────────────────
// PartRule — rules ตาม Part logic จาก add_question
// ─────────────────────────────────────────────────────────────────────────────
class _PartRule {
  static bool hasAudio(int part)   => [1, 2, 3, 4].contains(part);
  static bool hasGroup(int part)   => [3, 4, 6, 7].contains(part);
  static bool hasPassage(int part) => [6, 7].contains(part);
  static bool hasOptionD(int part) => part != 2; // Part 2: A/B/C only
  static bool hasImage(int part)   => part == 1; // Part 1 เท่านั้นมีรูปใน practice_test
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────
class AdminImportController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  ImportStep step          = ImportStep.idle;
  String     statusMsg     = '';
  int        progressOf    = 0;
  int        progressTotal = 0;

  List<PreviewRow>           previewRows   = [];
  List<Map<String, dynamic>> _rowsToInsert = [];
  List<Map<String, dynamic>> _passageRows  = [];
  ImportResult?              lastResult;

  void Function(String msg, {bool isError})? onSnack;

  int get previewNew       => previewRows.where((r) => r.status == 'new').length;
  int get previewDuplicate => previewRows.where((r) => r.status == 'duplicate').length;
  int get previewError     => previewRows.where((r) => r.status == 'error').length;
  int get previewPassages  => _passageRows.length;

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — validate (dry-run, ไม่แตะ DB)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> pickAndValidate() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (picked == null) return;

    _setState(ImportStep.validating, 'กำลังอ่านไฟล์...');

    try {
      List<List<dynamic>> fields = [];
      if (kIsWeb || picked.files.single.bytes != null) {
        fields = const CsvToListConverter()
            .convert(utf8.decode(picked.files.single.bytes!));
      } else {
        fields = const CsvToListConverter()
            .convert(await File(picked.files.single.path!).readAsString());
      }

      if (fields.length <= 1) throw 'ไฟล์ไม่มีข้อมูล หรือไม่มีหัวคอลัมน์';

      final header = fields[0]
          .map((e) => e.toString().trim().toLowerCase())
          .toList();

      for (final col in ['test_id', 'part', 'question_no']) {
        if (!header.contains(col)) throw 'ไม่พบคอลัมน์บังคับ: "$col"';
      }

      final idxTest = header.indexOf('test_id');
      final idxPart = header.indexOf('part');
      final idxQNo  = header.indexOf('question_no');

      _setState(ImportStep.validating, 'กำลังตรวจสอบกับ database...');
      final existingPracticeKeys  = await _fetchExistingPracticeKeys();
      final existingPassageGroups = await _fetchExistingPassageGroups();

      final dataRows  = fields.skip(1).toList();
      final totalRows = dataRows.length;
      _setState(ImportStep.validating, 'ตรวจสอบ $totalRows แถว...',
          progressOf: 0, progressTotal: totalRows);

      final preview     = <PreviewRow>[];
      final toInsert    = <Map<String, dynamic>>[];
      final passageRows = <Map<String, dynamic>>[];
      final errors      = <String>[];
      final passageGroupImages = <String, List<String>>{};

      for (int i = 0; i < dataRows.length; i++) {
        final row    = dataRows[i];
        final rowNum = i + 2;

        if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) continue;

        final tId  = int.tryParse(row[idxTest].toString().trim());
        final part = int.tryParse(row[idxPart].toString().trim());
        final qNo  = int.tryParse(row[idxQNo].toString().trim());

        // ── Basic validation ───────────────────────────────────────────────
        if (tId == null || part == null || qNo == null) {
          final msg = 'แถว $rowNum: test_id / part / question_no ต้องเป็นตัวเลข';
          errors.add(msg);
          preview.add(_errRow(rowNum, 0, 0, 0, _val(row, header, 'question_text'), msg));
          continue;
        }

        if (part < 1 || part > 7) {
          final msg = 'แถว $rowNum: part ต้องอยู่ระหว่าง 1-7 (พบ: $part)';
          errors.add(msg);
          preview.add(_errRow(rowNum, tId, part, qNo, _val(row, header, 'question_text'), msg));
          continue;
        }

        // ── Part-specific validation ───────────────────────────────────────
        final pgId     = _val(row, header, 'passage_group_id');
        final audioUrl = _val(row, header, 'audio_url');
        final imageUrl = _val(row, header, 'image_url');

        // Part 3/4/6/7: ต้องมี passage_group_id
        if (_PartRule.hasGroup(part) && pgId.isEmpty) {
          final msg = 'แถว $rowNum: Part $part ต้องมี passage_group_id '
              '(format: t${tId}p${part}g1, t${tId}p${part}g2, ...)';
          errors.add(msg);
          preview.add(_errRow(rowNum, tId, part, qNo, _val(row, header, 'question_text'), msg));
          continue;
        }

        // Part 1/2/3/4: ต้องมี audio_url
        if (_PartRule.hasAudio(part) && audioUrl.isEmpty) {
          final bucket = 'https://[project].supabase.co/storage/v1/object/public/exam-assets';
          final path   = 'T$tId/Listening/sound/[filename].mp3';
          final msg    = 'แถว $rowNum: Part $part ต้องมี audio_url\n'
              'Format: $bucket/$path';
          errors.add(msg);
          preview.add(_errRow(rowNum, tId, part, qNo, _val(row, header, 'question_text'), msg));
          continue;
        }

        // Part 1: ต้องมี image_url
        if (part == 1 && imageUrl.isEmpty) {
          final bucket = 'https://[project].supabase.co/storage/v1/object/public/exam-assets';
          final path   = 'T$tId/Listening/images/[filename].jpg';
          final msg    = 'แถว $rowNum: Part 1 ต้องมี image_url\n'
              'Format: $bucket/$path';
          errors.add(msg);
          preview.add(_errRow(rowNum, tId, part, qNo, _val(row, header, 'question_text'), msg));
          continue;
        }

        // Part 6/7 group ใหม่: ต้องมี image_url อย่างน้อย 1 ใบ
        if (_PartRule.hasPassage(part) && pgId.isNotEmpty) {
          final isNewGroup = !existingPassageGroups.contains(pgId) &&
              !passageGroupImages.containsKey(pgId);
          if (isNewGroup && imageUrl.isEmpty) {
            final bucket = 'https://[project].supabase.co/storage/v1/object/public/exam-assets';
            final path   = 'T$tId/Reading/[filename].jpg';
            final msg    = 'แถว $rowNum: Part $part group ใหม่ "$pgId" ต้องมี image_url\n'
                'Format: $bucket/$path';
            errors.add(msg);
            preview.add(_errRow(rowNum, tId, part, qNo, _val(row, header, 'question_text'), msg));
            continue;
          }
        }

        // ── ตรวจซ้ำ ─────────────────────────────────────────────────────
        final key = '$tId-$part-$qNo';
        if (existingPracticeKeys.contains(key)) {
          preview.add(PreviewRow(
            rowNum: rowNum, testId: tId, part: part, questionNo: qNo,
            questionText: _val(row, header, 'question_text'),
            status: 'duplicate',
          ));
          continue;
        }
        existingPracticeKeys.add(key);

        // ── Collect passage images (Part 6/7 group ใหม่เท่านั้น) ──────────
        bool willInsertPassage = false;
        if (_PartRule.hasPassage(part) && pgId.isNotEmpty &&
            !existingPassageGroups.contains(pgId)) {
          if (imageUrl.isNotEmpty) {
            passageGroupImages.putIfAbsent(pgId, () => []);
            if (!passageGroupImages[pgId]!.contains(imageUrl)) {
              passageGroupImages[pgId]!.add(imageUrl);
              willInsertPassage = true;
            }
          }
        }

        // ── Build payload ─────────────────────────────────────────────────
        toInsert.add({
          // *** ห้ามใส่ 'id' — ให้ Supabase auto-generate ***
          'test_id':     tId,
          'part':        part,
          'question_no': qNo,

          'question_text': _nullIfEmpty(_val(row, header, 'question_text')),
          'transcript':    _nullIfEmpty(_val(row, header, 'transcript')),

          'option_a': _nullIfEmpty(_val(row, header, 'option_a')),
          'option_b': _nullIfEmpty(_val(row, header, 'option_b')),
          'option_c': _nullIfEmpty(_val(row, header, 'option_c')),
          // Part 2: ไม่มี option_d ตาม logic ใน add_question
          'option_d': _PartRule.hasOptionD(part)
              ? _nullIfEmpty(_val(row, header, 'option_d'))
              : null,

          'correct_answer': _nullIfEmpty(_val(row, header, 'correct_answer')),
          'explanation':    _nullIfEmpty(_val(row, header, 'explanation')),
          'category':       _nullIfEmpty(_val(row, header, 'category')),
          'title':          _nullIfEmpty(_val(row, header, 'title')),

          'passage_group_id': pgId.isEmpty ? null : pgId,

          // audio_url: Part 1/2/3/4 เท่านั้น (Part 5/6/7 ไม่มีเสียง)
          'audio_url': _PartRule.hasAudio(part)
              ? _nullIfEmpty(audioUrl)
              : null,
          'start_time': _PartRule.hasAudio(part)
              ? (int.tryParse(_val(row, header, 'start_time')) ?? 0)
              : 0,
          'end_time': _PartRule.hasAudio(part)
              ? (int.tryParse(_val(row, header, 'end_time')) ?? 0)
              : 0,

          // image_url ใน practice_test:
          //   Part 1   → URL รูปโจทย์ (Listening/images/...)
          //   Part 2-5 → null (ไม่มีรูป)
          //   Part 6/7 → null (รูปอยู่ใน passages table แยก)
          'image_url': _PartRule.hasImage(part)
              ? _nullIfEmpty(imageUrl)
              : null,
        });

        preview.add(PreviewRow(
          rowNum: rowNum, testId: tId, part: part, questionNo: qNo,
          questionText: _val(row, header, 'question_text'),
          status: 'new',
          passageGroupId:    pgId.isEmpty ? null : pgId,
          willInsertPassage: willInsertPassage,
        ));

        if (i % 30 == 0) {
          _setState(ImportStep.validating,
              'ตรวจสอบแล้ว ${i + 1} / $totalRows...',
              progressOf: i + 1, progressTotal: totalRows);
        }
      }

      // ── Build passage rows (sequence = ลำดับที่ปรากฏใน CSV) ──────────────
      passageGroupImages.forEach((groupId, urls) {
        for (int seq = 0; seq < urls.length; seq++) {
          passageRows.add({
            'passage_group_id': groupId,
            'image_url':        urls[seq],
            'sequence':         seq + 1,
          });
        }
      });

      previewRows   = preview;
      _rowsToInsert = toInsert;
      _passageRows  = passageRows;
      _setState(ImportStep.preview, '');

    } catch (e) {
      onSnack?.call(e.toString(), isError: true);
      _setState(ImportStep.idle, '');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Insert จริง
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> confirmImport() async {
    if (_rowsToInsert.isEmpty) {
      onSnack?.call('ไม่มีแถวใหม่ที่จะนำเข้า');
      _setState(ImportStep.idle, '');
      return;
    }

    final totalOps = _rowsToInsert.length + _passageRows.length;
    _setState(ImportStep.importing, 'กำลังนำเข้าข้อมูล...',
        progressOf: 0, progressTotal: totalOps);

    final errors = <String>[];
    int imported         = 0;
    int passagesInserted = 0;
    const batchSize      = 50;

    // ── practice_test ──────────────────────────────────────────────────────
    for (int i = 0; i < _rowsToInsert.length; i += batchSize) {
      final batch = _rowsToInsert.sublist(
          i, (i + batchSize).clamp(0, _rowsToInsert.length));
      try {
        await _supabase.from('practice_test').insert(batch);
        imported += batch.length;
      } catch (_) {
        // fallback: row-by-row เพื่อหา row ที่ผิดจริง
        for (final row in batch) {
          try {
            await _supabase.from('practice_test').insert(row);
            imported++;
          } catch (e2) {
            errors.add('T${row['test_id']}-P${row['part']}-Q${row['question_no']}: $e2');
          }
        }
      }
      _setState(ImportStep.importing,
          'นำเข้าข้อสอบแล้ว $imported / ${_rowsToInsert.length}...',
          progressOf: imported, progressTotal: totalOps);
    }

    // ── passages (Part 6/7 groups ใหม่เท่านั้น) ───────────────────────────
    // *** ไม่ DELETE passages เดิม *** ต่างจาก savePassageImages() ใน add_question
    // เหตุผล: CSV import ไม่รู้ว่า group นั้นมีรูปอื่นอยู่แล้วกี่ใบ
    //         ถ้า DELETE จะสูญรูปที่ admin upload ผ่าน add_question ไปแล้ว
    if (_passageRows.isNotEmpty) {
      _setState(ImportStep.importing, 'กำลัง insert Passage images...',
          progressOf: imported, progressTotal: totalOps);

      for (int i = 0; i < _passageRows.length; i += batchSize) {
        final batch = _passageRows.sublist(
            i, (i + batchSize).clamp(0, _passageRows.length));
        try {
          await _supabase.from('passages').insert(batch);
          passagesInserted += batch.length;
        } catch (_) {
          for (final row in batch) {
            try {
              await _supabase.from('passages').insert(row);
              passagesInserted++;
            } catch (e2) {
              errors.add('passages ${row['passage_group_id']} seq${row['sequence']}: $e2');
            }
          }
        }
        _setState(ImportStep.importing,
            'insert passages $passagesInserted / ${_passageRows.length}...',
            progressOf: imported + passagesInserted, progressTotal: totalOps);
      }
    }

    lastResult = ImportResult(
      imported:         imported,
      duplicates:       previewDuplicate,
      skipped:          previewError,
      passagesInserted: passagesInserted,
      errors:           errors,
      duplicateIds:     previewRows
          .where((r) => r.status == 'duplicate')
          .map((r) => 'T${r.testId}-P${r.part}-Q${r.questionNo}')
          .toList(),
    );
    _rowsToInsert = [];
    _passageRows  = [];
    previewRows   = [];
    _setState(ImportStep.done, '');
  }

  void cancelPreview() {
    previewRows   = [];
    _rowsToInsert = [];
    _passageRows  = [];
    _setState(ImportStep.idle, '');
  }

  void reset() {
    lastResult    = null;
    previewRows   = [];
    _rowsToInsert = [];
    _passageRows  = [];
    _setState(ImportStep.idle, '');
  }

  // ── DB helpers ──────────────────────────────────────────────────────────────
  Future<Set<String>> _fetchExistingPracticeKeys() async {
    final rows = await _supabase
        .from('practice_test')
        .select('test_id, part, question_no');
    return {
      for (final r in rows as List)
        '${r['test_id']}-${r['part']}-${r['question_no']}'
    };
  }

  Future<Set<String>> _fetchExistingPassageGroups() async {
    final rows = await _supabase.from('passages').select('passage_group_id');
    return {for (final r in rows as List) r['passage_group_id'].toString()};
  }

  PreviewRow _errRow(int rowNum, int tId, int part, int qNo,
      String qText, String msg) =>
      PreviewRow(
        rowNum: rowNum, testId: tId, part: part, questionNo: qNo,
        questionText: qText, status: 'error', errorMsg: msg,
      );

  String _val(List<dynamic> row, List<dynamic> header, String col) {
    final idx = header.indexOf(col);
    return (idx != -1 && idx < row.length) ? row[idx].toString().trim() : '';
  }

  String? _nullIfEmpty(String s) => s.isEmpty ? null : s;

  void _setState(ImportStep s, String msg,
      {int progressOf = 0, int progressTotal = 0}) {
    step               = s;
    statusMsg          = msg;
    this.progressOf    = progressOf;
    this.progressTotal = progressTotal;
    notifyListeners();
  }
  
}
