import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// AdminQuestionController — แยก business logic ออกจาก UI
// ใช้ ChangeNotifier เพื่อ notify Screen ให้ rebuild
// ─────────────────────────────────────────────────────────────────────────────
class AdminQuestionController extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isGeneratingAI = false;
  String loadingMessage = '';

  // ── Controllers ────────────────────────────────────────────────────────────
  late TextEditingController testIdCtrl;
  late TextEditingController qNoCtrl;
  late TextEditingController qTextCtrl;
  late TextEditingController transcriptCtrl;
  late TextEditingController optACtrl, optBCtrl, optCCtrl, optDCtrl;
  late TextEditingController explanationCtrl;
  late TextEditingController categoryCtrl;
  late TextEditingController audioUrlCtrl;
  late TextEditingController imageUrlCtrl;
  late TextEditingController startTimeCtrl;
  late TextEditingController endTimeCtrl;
  late TextEditingController newGroupCtrl;

  // ── Form values ─────────────────────────────────────────────────────────────
  String selectedCorrectAnswer = 'A';
  int selectedPart = 1;
  String? testTitle;

  // ── Passage group ───────────────────────────────────────────────────────────
  List<String> existingGroups = [];
  String? selectedPassageGroup;
  bool createNewGroup = false;
  List<String> passageImages = [];
  bool loadingPassageImages = false;

  // ── Callbacks (set by screen) ───────────────────────────────────────────────
  void Function(String)? onSnack;
  void Function()? onSaved;

  // ─────────────────────────────────────────────────────────────────────────
  void init({
    required Map<String, dynamic>? editData,
    required Map<String, dynamic>? initialData,
  }) {
    final d = editData;
    final init = initialData;

    selectedPart = d?['part'] ?? init?['part'] ?? 1;
    selectedCorrectAnswer = d?['correct_answer'] ?? 'A';
    testTitle = init?['test_title'] ?? d?['title'];

    testIdCtrl = TextEditingController(
      text: (d?['test_id'] ?? init?['test_id'])?.toString() ?? '',
    );
    qNoCtrl = TextEditingController(text: d?['question_no']?.toString() ?? '');
    qTextCtrl = TextEditingController(text: d?['question_text'] ?? '');
    transcriptCtrl = TextEditingController(text: d?['transcript'] ?? '');
    optACtrl = TextEditingController(text: d?['option_a'] ?? '');
    optBCtrl = TextEditingController(text: d?['option_b'] ?? '');
    optCCtrl = TextEditingController(text: d?['option_c'] ?? '');
    optDCtrl = TextEditingController(text: d?['option_d'] ?? '');
    explanationCtrl = TextEditingController(text: d?['explanation'] ?? '');
    categoryCtrl = TextEditingController(text: d?['category'] ?? '');
    audioUrlCtrl = TextEditingController(text: d?['audio_url'] ?? '');
    imageUrlCtrl = TextEditingController(text: d?['image_url'] ?? '');
    startTimeCtrl = TextEditingController(
      text: d?['start_time']?.toString() ?? '0',
    );
    endTimeCtrl = TextEditingController(
      text: d?['end_time']?.toString() ?? '0',
    );
    newGroupCtrl = TextEditingController();

    // rebuild UI เมื่อ URL เปลี่ยน (สลับ "ยังไม่มีไฟล์" ↔ status card)
    audioUrlCtrl.addListener(notifyListeners);
    imageUrlCtrl.addListener(notifyListeners);

    final pgId = d?['passage_group_id']?.toString().trim() ?? '';
    if (pgId.isNotEmpty) selectedPassageGroup = pgId;

    fetchInitialData();
  }

  // ─────────────────────────────────────────────────────────────────────────
  void dispose2() {
    for (final c in [
      testIdCtrl,
      qNoCtrl,
      qTextCtrl,
      transcriptCtrl,
      optACtrl,
      optBCtrl,
      optCCtrl,
      optDCtrl,
      explanationCtrl,
      categoryCtrl,
      audioUrlCtrl,
      imageUrlCtrl,
      startTimeCtrl,
      endTimeCtrl,
      newGroupCtrl,
    ]) {
      c.dispose();
    }
  }

  void _setLoading(bool v, [String msg = '']) {
    isLoading = v;
    loadingMessage = msg;
    notifyListeners();
  }

  void _setAI(bool v) {
    isGeneratingAI = v;
    notifyListeners();
  }

  void _snack(String msg) => onSnack?.call(msg);

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> fetchInitialData() async {
    if (testIdCtrl.text.isEmpty) return;
    try {
      if (testTitle == null) {
        final res = await _supabase
            .from('exam_sets')
            .select('title')
            .eq('test_id', int.parse(testIdCtrl.text))
            .maybeSingle();
        if (res != null) {
          testTitle = res['title'];
          notifyListeners();
        }
      }
      await _fetchPassageGroups();
    } catch (e) {
      debugPrint('fetchInitialData: $e');
    }
    if (qNoCtrl.text.isEmpty) await _fetchNextQuestionNo();
  }

  Future<void> _fetchNextQuestionNo() async {
    try {
      final res = await _supabase
          .from('practice_test')
          .select('question_no')
          .eq('test_id', int.parse(testIdCtrl.text))
          .order('question_no', ascending: false)
          .limit(1)
          .maybeSingle();
      qNoCtrl.text = res != null ? '${res['question_no'] + 1}' : '1';
    } catch (_) {
      qNoCtrl.text = '1';
    }
  }

  Future<void> _fetchPassageGroups() async {
    try {
      final res = await _supabase
          .from('practice_test')
          .select('passage_group_id')
          .eq('test_id', int.parse(testIdCtrl.text))
          .eq('part', selectedPart);
      existingGroups =
          (res as List)
              .map((e) => e['passage_group_id']?.toString().trim() ?? '')
              .where((g) => g.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      notifyListeners();
      if (selectedPassageGroup != null)
        await fetchPassageImages(selectedPassageGroup!);
    } catch (_) {}
  }

  Future<void> fetchPassageImages(String groupId) async {
    loadingPassageImages = true;
    passageImages = [];
    notifyListeners();
    try {
      final res = await _supabase
          .from('passages')
          .select('image_url, sequence')
          .eq('passage_group_id', groupId)
          .order('sequence', ascending: true);
      passageImages = (res as List)
          .map((e) => e['image_url']?.toString() ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
    } catch (_) {
      passageImages = [];
    }
    loadingPassageImages = false;
    notifyListeners();
  }

  Future<String> generateGroupId() async {
    final tId = testIdCtrl.text.trim();
    final prefix = 't${tId}p${selectedPart}g';
    final res = await _supabase
        .from('practice_test')
        .select('passage_group_id')
        .eq('test_id', int.parse(tId))
        .eq('part', selectedPart)
        .not('passage_group_id', 'is', null);
    int maxN = 0;
    for (final row in (res as List)) {
      final gId = row['passage_group_id']?.toString() ?? '';
      if (gId.startsWith(prefix)) {
        final n = int.tryParse(gId.substring(prefix.length)) ?? 0;
        if (n > maxN) maxN = n;
      }
    }
    return '$prefix${maxN + 1}';
  }

  Future<void> savePassageImages(String groupId, List<String> urls) async {
    if (urls.isEmpty) return;
    await _supabase.from('passages').delete().eq('passage_group_id', groupId);
    await _supabase
        .from('passages')
        .insert(
          urls
              .asMap()
              .entries
              .map(
                (e) => {
                  'passage_group_id': groupId,
                  'image_url': e.value,
                  'sequence': e.key + 1,
                },
              )
              .toList(),
        );
  }

  // ── Part / Group helpers ────────────────────────────────────────────────────
  void onPartChanged(int part) {
    selectedPart = part;
    selectedPassageGroup = null;
    existingGroups = [];
    passageImages = [];
    notifyListeners();
    fetchInitialData();
  }

  void selectGroup(String? groupId) {
    selectedPassageGroup = groupId;
    passageImages = [];
    notifyListeners();
    if (groupId != null) fetchPassageImages(groupId);
  }

  // ── Group ID warning (เตือนเมื่อ ID ที่กรอกมีรูปใน passages แล้ว) ───────────
  String? groupIdWarning;
  bool checkingGroupId = false;

  void setCreateNewGroup(bool v) {
    createNewGroup = v;
    if (v) {
      selectedPassageGroup = null;
      passageImages = [];
      groupIdWarning = null;
    }
    notifyListeners();
  }

  /// เรียกทุกครั้งที่ admin พิมพ์ใน newGroupCtrl
  /// ถ้า ID นั้นมีรูปใน passages table → set warning
  Future<void> checkGroupIdConflict(String groupId) async {
    groupId = groupId.trim();
    if (groupId.isEmpty) {
      groupIdWarning = null;
      checkingGroupId = false;
      notifyListeners();
      return;
    }
    checkingGroupId = true;
    groupIdWarning = null;
    notifyListeners();
    try {
      final res = await _supabase
          .from('passages')
          .select('id, image_url, sequence')
          .eq('passage_group_id', groupId)
          .order('sequence', ascending: true);
      final list = List<Map<String, dynamic>>.from(res as List);
      if (list.isNotEmpty) {
        groupIdWarning =
            '⚠️ มี Group ID "$groupId" อยู่แล้วในระบบ (มีรูป ${list.length} รูป) \n'
            'ถ้าอัปโหลดรูปใหม่ รูปเดิมจะถูกแทนที่ทั้งหมด';
      } else {
        groupIdWarning = null;
      }
    } catch (_) {
      groupIdWarning = null;
    }
    checkingGroupId = false;
    notifyListeners();
  }

  void removePassageImage(int index) {
    passageImages.removeAt(index);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD — ใช้ HTML input โดยตรง (วิธีเดียวที่ reliable บน Flutter Web)
  // ─────────────────────────────────────────────────────────────────────────

  /// เปิด file picker ผ่าน HTML input element โดยตรง
  /// Flutter Web: FilePicker withData มักไม่ return bytes → ใช้วิธีนี้แทน
  Future<List<_PickedFile>> _pickFilesWeb({
    required List<String> accept, // เช่น ['.mp3','.wav'] หรือ ['image/*']
    bool multiple = false,
  }) {
    final completer = Completer<List<_PickedFile>>();

    final input = html.FileUploadInputElement()
      ..accept = accept.join(',')
      ..multiple = multiple;

    input.onChange.listen((_) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete([]);
        return;
      }
      final picked = <_PickedFile>[];
      for (final file in files) {
        final reader = html.FileReader();
        final c = Completer<Uint8List>();
        reader.onLoadEnd.listen((_) {
          c.complete(reader.result as Uint8List);
        });
        reader.readAsArrayBuffer(file);
        final bytes = await c.future;
        picked.add(_PickedFile(name: file.name, bytes: bytes));
      }
      completer.complete(picked);
    });

    // ถ้า user กด cancel
    input.onAbort.listen((_) => completer.complete([]));

    // trigger click
    input.click();
    return completer.future;
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'aac':
        return 'audio/aac';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  /// อัปโหลด audio หรือ image เดี่ยว (สำหรับ audio section และ Part 1)
  Future<void> uploadFile(String type) async {
    if (testIdCtrl.text.trim().isEmpty) {
      _snack('⚠️ ไม่มี Test ID');
      return;
    }

    final accept = type == 'audio'
        ? ['.mp3', '.m4a', '.wav', '.ogg', '.aac']
        : ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

    final picked = await _pickFilesWeb(accept: accept, multiple: false);
    if (picked.isEmpty) return;

    final file = picked.first;
    _setLoading(true, 'กำลังอัปโหลด ${file.name}...');

    try {
      final tId      = testIdCtrl.text.trim();
      final ext      = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'bin';
      // ใช้ชื่อไฟล์จริงที่ admin อัปโหลด (sanitize: แทนที่ space ด้วย _)
      final safeName = file.name.replaceAll(' ', '_');

      final String path;
      if (type == 'audio') {
        path = 'T$tId/Listening/sound/$safeName';
      } else if (selectedPart == 1) {
        path = 'T$tId/Listening/images/$safeName';
      } else {
        path = 'T$tId/Reading/$safeName';
      }

      await _supabase.storage
          .from('exam-assets')
          .uploadBinary(
            path,
            file.bytes,
            fileOptions: FileOptions(
              contentType: _getMimeType(ext),
              upsert: true,
            ),
          );

      final url = _supabase.storage.from('exam-assets').getPublicUrl(path);
      if (type == 'image')
        imageUrlCtrl.text = url;
      else
        audioUrlCtrl.text = url;
      notifyListeners();
      _snack('✅ อัปโหลดสำเร็จ: ${file.name}');
    } catch (e) {
      _snack('❌ อัปโหลดล้มเหลว: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// อัปโหลดรูปหลายรูปสำหรับ Passage Group (Part 6-7)
  Future<void> uploadPassageImages() async {
    if (testIdCtrl.text.trim().isEmpty) {
      _snack('⚠️ ไม่มี Test ID');
      return;
    }

    final picked = await _pickFilesWeb(
      accept: ['.jpg', '.jpeg', '.png', '.webp', '.gif'],
      multiple: true,
    );
    if (picked.isEmpty) return;

    _setLoading(true, 'กำลังอัปโหลด ${picked.length} รูป...');
    try {
      final tId = testIdCtrl.text.trim();
      final groupSuffix = selectedPassageGroup ?? newGroupCtrl.text.trim();
      final subfolder = selectedPart >= 6
          ? 'T$tId/Reading${groupSuffix.isNotEmpty ? "/$groupSuffix" : ""}'
          : 'T$tId/Listening/images';

      final newUrls = <String>[];
      for (final file in picked) {
        final ext      = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : 'jpg';
        // ใช้ชื่อไฟล์จริง (sanitize space → _)
        final safeName = file.name.replaceAll(' ', '_');
        final path     = '$subfolder/$safeName';

        await _supabase.storage
            .from('exam-assets')
            .uploadBinary(
              path,
              file.bytes,
              fileOptions: FileOptions(
                contentType: _getMimeType(ext),
                upsert: true,
              ),
            );
        newUrls.add(_supabase.storage.from('exam-assets').getPublicUrl(path));
        await Future.delayed(const Duration(milliseconds: 5));
      }
      passageImages.addAll(newUrls);
      notifyListeners();
      _snack('✅ อัปโหลด ${newUrls.length} รูปสำเร็จ');
    } catch (e) {
      _snack('❌ อัปโหลดล้มเหลว: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Storage Browser ────────────────────────────────────────────────────────

  /// list ไฟล์ recursive 2 ระดับ (Supabase .list() ไม่ recursive)
  Future<Map<String, String>> listFilesRecursive(
    String rootPath,
    Set<String> allowedExts,
  ) async {
    final bucket = _supabase.storage.from('exam-assets');
    final result = <String, String>{};
    List<dynamic> items = [];
    try {
      items = await bucket.list(path: rootPath);
    } catch (_) {
      return result;
    }

    for (final item in items) {
      final name = item.name as String;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      if (ext.isNotEmpty && allowedExts.contains(ext)) {
        result[name] = '$rootPath/$name';
      } else if (ext.isEmpty) {
        // น่าจะเป็น subfolder → list อีกชั้น
        try {
          final sub = await bucket.list(path: '$rootPath/$name');
          for (final s in sub) {
            final sName = s.name; 
            final sExt = sName.contains('.')
                ? sName.split('.').last.toLowerCase()
                : '';
            if (sExt.isNotEmpty && allowedExts.contains(sExt)) {
              result['$name/$sName'] = '$rootPath/$name/$sName';
            }
          }
        } catch (_) {}
      }
    }
    return result;
  }

  Future<Map<String, String>> browseStorageFiles(String type) async {
    final tId = testIdCtrl.text.trim();
    const audioExts = {'mp3', 'm4a', 'wav', 'ogg', 'aac'};
    const imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
    final allowedExts = type == 'audio' ? audioExts : imageExts;

    final List<String> rootPaths;
    if (type == 'audio') {
      rootPaths = ['T$tId/Listening/sound', 'T$tId/Listening'];
    } else if (selectedPart <= 4) {
      rootPaths = ['T$tId/Listening/images', 'T$tId/Listening'];
    } else {
      rootPaths = ['T$tId/Reading'];
    }

    final found = <String, String>{};
    for (final root in rootPaths) {
      final files = await listFilesRecursive(root, allowedExts);
      found.addAll(files);
      if (found.isNotEmpty && type == 'audio') break;
    }
    return found;
  }

  void setAudioUrl(String url) {
    audioUrlCtrl.text = url;
    notifyListeners();
  }

  void setImageUrl(String url) {
    imageUrlCtrl.text = url;
    notifyListeners();
  }

  void addPassageImageUrls(List<String> urls) {
    passageImages.addAll(urls);
    notifyListeners();
  }

  // ── AI ─────────────────────────────────────────────────────────────────────
  Future<void> aiScanImages(List<String> imageUrls) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _snack('❌ ไม่พบ GEMINI_API_KEY');
      return;
    }
    if (imageUrls.isEmpty) {
      _snack('⚠️ ไม่มีรูปให้ scan');
      return;
    }
    _setAI(true);
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(temperature: 0.1),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );
      final parts = <DataPart>[];
      for (final url in imageUrls) {
        final r = await http.get(Uri.parse(url));
        parts.add(DataPart('image/jpeg', r.bodyBytes));
      }
      const prompt =
          '''As an educational assistant, digitize the text from these images.
- Transcribe exactly as it appears. Separate images with "---".
- Keep numbers, blanks (e.g. [131]), punctuation.
- Output ONLY plain text.''';
      final res = await model.generateContent([
        Content.multi([TextPart(prompt), ...parts]),
      ]);
      if (res.text != null) {
        transcriptCtrl.text = res.text!;
        if (selectedPart == 6 && qTextCtrl.text.isEmpty)
          qTextCtrl.text =
              'Select the best word or phrase to complete the sentence.';
        else if (selectedPart == 7 && qTextCtrl.text.isEmpty)
          qTextCtrl.text = 'Refer to the text to answer the question.';
        notifyListeners();
        _snack('✅ AI Scan ${imageUrls.length} รูปสำเร็จ');
      }
    } catch (e) {
      _snack('AI Scan Error: $e');
    } finally {
      _setAI(false);
    }
  }

  Future<void> aiGenerateExplanation() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _snack('❌ ไม่พบ GEMINI_API_KEY');
      return;
    }
    final isListening = selectedPart >= 1 && selectedPart <= 4;
    final isReading = selectedPart == 6 || selectedPart == 7;
    if ((isListening || isReading) && transcriptCtrl.text.trim().isEmpty) {
      _snack('⚠️ กรุณากรอก Transcript ก่อน');
      return;
    }
    _setAI(true);
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final prompt =
    '''You are an expert TOEIC tutor with a perfect 990 score.
Your task: classify the question into exactly one category, then explain in Thai.

LANGUAGE RULE: All explanations must be written entirely in Thai.
Category names must remain in English exactly as defined in the rules.

════════════════════════════════════════
TOEIC STRUCTURE & CLASSIFICATION RULES
════════════════════════════════════════

PART 1 — Listening: Photographs
  Context: Test-taker sees 1 photo. Hears 4 sentences. Picks the sentence that best describes the photo.
  Rule: ALWAYS classify as "Graphic Content"

PART 2 — Listening: Question-Response
  Context: Hears 1 question or statement. Picks the best response from A/B/C (no D option).
  Rule: ALWAYS classify as "Detail"

PART 3 — Listening: Conversations
  Context: Hears a conversation between 2-3 people. Answers 3 questions per conversation.
  Some questions are paired with a graphic (schedule, map, coupon, list, etc.)
  Rules:
    - If question says "Look at the graphic" or answer requires reading the visual → "Graphic Content"
    - If question asks what the conversation is mainly about / purpose of the call → "Main Idea"
    - If question asks for a specific stated fact (When, Where, Who, What, How many/much) → "Detail"
    - If question uses words like "implied", "suggested", "most likely", "probably", "inferred" → "Inference"
    - If question asks what someone will do next / next action → "Detail"

PART 4 — Listening: Talks
  Context: Hears a monologue (announcement, voicemail, broadcast, etc.). Answers 3 questions per talk.
  Some questions are paired with a graphic (schedule, map, chart, etc.)
  Rules: Same as Part 3 rules above.

PART 5 — Reading: Incomplete Sentences
  Context: Single sentence with one blank. Choose the word that best completes the sentence.
  Rule: Classify by grammar or vocabulary point:
    Part of Speech     — choosing noun/verb/adjective/adverb form of the same root word
    Tense              — selecting the correct verb tense or aspect
    Passive Voice      — choosing between active and passive verb form
    Subject-Verb Agreement — singular/plural verb matching subject
    Preposition & Conjunction — choosing the correct preposition or linking word
    Comparison         — comparative/superlative forms
    Pronoun            — choosing the correct pronoun case or type
    Participle         — present/past participle used as adjective or in a phrase
    Collocation        — fixed word combinations (e.g. "make a decision", "heavy traffic")
    Vocabulary         — choosing the correct word by meaning when grammar is not the key issue

PART 6 — Reading: Text Completion
  Context: Short passage (email, memo, notice) with 4 blanks. One blank may require inserting a full sentence.
  Rule: Use the same 10 grammar/vocabulary categories as Part 5.
    Additionally, if the blank requires inserting a complete sentence that connects ideas → "Cohesion"

PART 7 — Reading: Reading Comprehension
  Context: Single or multiple passages (email, article, advertisement, chat, form, etc.). Answers 2-5 questions per set.
  Some questions require reading an embedded graphic (table, chart, coupon, schedule, etc.)
  Rules:
    - If question says "Look at the ...", or answer cannot be found without reading a visual → "Graphic Content"
    - If question asks what the passage is mainly about / purpose of the text / why it was written → "Main Idea"
    - If question asks for a specific fact stated in the text (When, Where, Who, What, How) → "Detail"
    - If question uses "implied", "suggested", "most likely", "inferred", "can be concluded" → "Inference"
    - If question asks what a word/phrase "most nearly means" in context → "Vocabulary in Context"
    - If question asks the reader to find where a sentence would best fit in the passage → "Sentence Insertion"

════════════════════════════════════════
INPUT
════════════════════════════════════════
Part: $selectedPart
Transcript / Passage: ${transcriptCtrl.text}
Question: ${qTextCtrl.text}
A: ${optACtrl.text}
B: ${optBCtrl.text}
C: ${optCCtrl.text}
D: ${optDCtrl.text}
Correct answer: $selectedCorrectAnswer

════════════════════════════════════════
OUTPUT — strictly valid JSON, nothing else
════════════════════════════════════════
{
  "category": "<exactly one category name in English from the rules above>",
  "explanation": "1. คำแปล: <แปลโจทย์และตัวเลือกทุกข้อเป็นภาษาไทยให้ครบ>\\n2. วิเคราะห์: <อธิบายเป็นภาษาไทยว่าทำไมคำตอบที่ถูกถึงถูก โดยอ้างอิงจากเนื้อหา>\\n3. ตัดตัวเลือก: <อธิบายเป็นภาษาไทยว่าทำไมแต่ละตัวเลือกที่ผิดถึงผิด>\\n4. ศัพท์น่ารู้: <3-5 คำพร้อมความหมายภาษาไทยและตัวอย่างประโยค>"
}

HARD CONSTRAINTS — never violate:
- Output JSON only. Zero text before or after the JSON block.
- Plain text inside all string values. No *, **, #, ##, -, or any Markdown symbols.
- explanation must be written in Thai only. Never switch to English inside explanation.
- Do not mention rule numbers, part comparisons, or classification logic in the explanation.
- Analyze only the content of this specific question.
''';

      final res = await model.generateContent([Content.text(prompt)]);
      if (res.text != null) {
        final raw = res.text!
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        categoryCtrl.text = data['category'] ?? '';
        explanationCtrl.text = data['explanation'] ?? '';
        notifyListeners();
        _snack('✅ AI วิเคราะห์เสร็จแล้ว');
      }
    } catch (e) {
      _snack('AI Error: $e');
    } finally {
      _setAI(false);
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> saveData(bool isEdit, int? editId) async {
    if (testIdCtrl.text.trim().isEmpty) {
      _snack('⚠️ ไม่มี Test ID');
      return;
    }

    _setLoading(true, 'กำลังบันทึก...');
    try {
      final tId = int.parse(testIdCtrl.text);
      final qNo = int.parse(qNoCtrl.text);

      if (!isEdit) {
        final dup = await _supabase
            .from('practice_test')
            .select('id')
            .eq('test_id', tId)
            .eq('question_no', qNo)
            .maybeSingle();
        if (dup != null) {
          _snack('❌ ข้อที่ $qNo มีอยู่แล้วใน Test $tId');
          _setLoading(false);
          return;
        }
      }

      // ── Passage Group ──
      String? finalGroupId;
      final isGroupPart =
          selectedPart == 3 || selectedPart == 4 || selectedPart >= 6;
      if (isGroupPart) {
        if (createNewGroup) {
          finalGroupId = newGroupCtrl.text.trim().isNotEmpty
              ? newGroupCtrl.text.trim()
              : await generateGroupId();
        } else {
          finalGroupId = selectedPassageGroup;
        }
        if (finalGroupId != null &&
            passageImages.isNotEmpty &&
            selectedPart >= 6) {
          _setLoading(true, 'บันทึกรูป Passage...');
          await savePassageImages(finalGroupId, passageImages);
        }
      }

      final payload = {
        'test_id': tId,
        'title': testTitle,
        'part': selectedPart,
        'question_no': qNo,
        'question_text': qTextCtrl.text.trim(),
        'transcript': transcriptCtrl.text.trim(),
        'option_a': optACtrl.text.trim(),
        'option_b': optBCtrl.text.trim(),
        'option_c': optCCtrl.text.trim(),
        'option_d': optDCtrl.text.trim(),
        'correct_answer': selectedCorrectAnswer,
        'explanation': explanationCtrl.text.trim(),
        'category': categoryCtrl.text.trim(),
        'passage_group_id': finalGroupId,
        'audio_url': audioUrlCtrl.text.trim(),
        'image_url': (selectedPart >= 6 && finalGroupId != null)
            ? ''
            : imageUrlCtrl.text.trim(),
        'start_time': int.tryParse(startTimeCtrl.text) ?? 0,
        'end_time': int.tryParse(endTimeCtrl.text) ?? 0,
      };

      if (isEdit && editId != null) {
        await _supabase.from('practice_test').update(payload).eq('id', editId);
      } else {
        await _supabase.from('practice_test').insert(payload);
      }
      onSaved?.call();
    } catch (e) {
      _snack('Save Error: $e');
    } finally {
      _setLoading(false);
    }
  }

  String partName(int p) {
    const names = [
      'Photographs',
      'Questions & Responses',
      'Conversations',
      'Short Talks',
      'Incomplete Sentences',
      'Text Completion',
      'Reading Comprehension',
    ];
    return names[p - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PickedFile {
  final String name;
  final Uint8List bytes;
  const _PickedFile({required this.name, required this.bytes});
}
