import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../../models/vocab_model.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminVocabController — business logic ทั้งหมด
// ไม่รู้จัก BuildContext หรือ Widget
// Screen ฟัง state ผ่าน ChangeNotifier
// ─────────────────────────────────────────────────────────────────────────────
class AdminVocabController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  static const String _tableName = 'vocabularies';

  // ── State ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> allData = [];
  bool isLoading = true;
  bool isAiLoading = false;

  // ── Filter / Search state ──────────────────────────────────────────────────
  String searchQuery = '';
  String selectedLetter = 'All';
  String selectedCEFR = 'All';

  // ── Callbacks → Screen แสดง SnackBar ──────────────────────────────────────
  void Function(String msg, {bool isError, bool isWarning})? onSnack;

  // ─────────────────────────────────────────────────────────────────────────
  // DATA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> refreshData() async {
    isLoading = true;
    notifyListeners();

    const pageSize = 1000;

    try {
      // Step 1: นับ rows จริงก่อน
      final countRes = await _supabase
          .from(_tableName)
          .select('id')
          .count(CountOption.exact);
      final total = countRes.count;

      // Step 2: คำนวณจำนวน page แล้วยิงทุก page พร้อมกัน (parallel)
      final pageCount = (total / pageSize).ceil();
      final futures = List.generate(pageCount, (i) {
        final from = i * pageSize;
        return _supabase
            .from(_tableName)
            .select()
            .order('id', ascending: false)
            .range(from, from + pageSize - 1);
      });

      // Step 3: รอทุก request พร้อมกัน
      final results = await Future.wait(futures);
      allData = results
          .expand((page) => List<Map<String, dynamic>>.from(page))
          .toList();

      isLoading = false;
    } catch (e) {
      debugPrint('refreshData error: $e');
      isLoading = false;
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER
  // ─────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get filteredData {
    final q = searchQuery.toLowerCase().trim();

    final result = allData.where((d) {
      final v = Vocabulary.fromMap(d);
      final id = (d['id'] ?? '').toString();

      final matchesSearch =
          q.isEmpty ||
          id.contains(q) ||
          v.headword.toLowerCase().contains(q) ||
          v.translationTH.toLowerCase().contains(q);

      final matchesLetter =
          selectedLetter == 'All' ||
          v.headword.toLowerCase().startsWith(selectedLetter.toLowerCase());

      final matchesCEFR =
          selectedCEFR == 'All' ||
          v.cefr.toUpperCase() == selectedCEFR.toUpperCase();

      return matchesSearch && matchesLetter && matchesCEFR;
    }).toList();

    result.sort((a, b) {
      final A = (a['headword'] ?? '').toString().toLowerCase();
      final B = (b['headword'] ?? '').toString().toLowerCase();
      return A.compareTo(B);
    });

    return result;
  }

  bool get hasActiveFilter =>
      searchQuery.isNotEmpty ||
      selectedLetter != 'All' ||
      selectedCEFR != 'All';

  void setSearch(String v) {
    searchQuery = v.trim();
    notifyListeners();
  }

  void setLetter(String v) {
    selectedLetter = v;
    notifyListeners();
  }

  void setCEFR(String v) {
    selectedCEFR = v;
    notifyListeners();
  }

  void clearFilters() {
    searchQuery = '';
    selectedLetter = 'All';
    selectedCEFR = 'All';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI FILL
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, String>?> fetchAiData(String word, String pos) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('Error: GEMINI_API_KEY not found in .env');
      return null;
    }

    isAiLoading = true;
    notifyListeners();

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    final prompt =
        '''
Provide vocabulary information for the word "$word" with part of speech "$pos".
Return the result in JSON format only with the following keys:
{
  "CEFR": "Level (A1, A2, B1, B2, C1, or C2)",
  "Reading_EN": "IPA or phonetic transcription",
  "Reading_TH": "Thai phonetic equivalent",
  "Translation_TH": "Thai translation",
  "Definition_TH": "short Thai definition",
  "Definition_EN": "short English definition",
  "Example_Sentence": "one clear English example sentence using the word",
  "TOEIC_Category": "common TOEIC topic like Office, Travel, Finance",
  "Synonyms": "2-3 synonyms separated by comma"
}
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text != null) {
        final Map<String, dynamic> decoded = jsonDecode(response.text!);
        isAiLoading = false;
        notifyListeners();
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      debugPrint('Gemini AI Error: $e');
      onSnack?.call('AI Error: ${e.toString()}', isError: true);
    }

    isAiLoading = false;
    notifyListeners();
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE (insert / update)
  // ─────────────────────────────────────────────────────────────────────────

  /// คืนค่า true = สำเร็จ, false = มีข้อผิดพลาด
  Future<bool> saveVocab({
    required Map<String, dynamic>? existingData,
    required String headword,
    required String pos,
    required String cefr,
    required String readingEn,
    required String readingTh,
    required String translationTH,
    required String definitionTH,
    required String definitionEN,
    required String exampleSentence,
    required String toeicCategory,
    required String synonyms,
  }) async {
    if (headword.isEmpty || pos.isEmpty) return false;

    // เช็คซ้ำก่อนบันทึก (เฉพาะ add ใหม่)
    if (existingData == null) {
      final dup = await _supabase
          .from(_tableName)
          .select('id')
          .eq('headword', headword)
          .eq('pos', pos)
          .maybeSingle();
      if (dup != null) {
        onSnack?.call(
          "❌ '$headword ($pos)' มีอยู่ในระบบแล้ว!",
          isWarning: true,
        );
        return false;
      }
    }

    final payload = {
      if (existingData != null) 'id': existingData['id'],
      'headword': headword,
      'pos': pos,
      'CEFR': cefr.toUpperCase(),
      'Reading_EN': readingEn,
      'Reading_TH': readingTh,
      'Translation_TH': translationTH,
      'Definition_TH': definitionTH,
      'Definition_EN': definitionEN,
      'Example_Sentence': exampleSentence,
      'TOEIC_Category': toeicCategory,
      'Synonyms': synonyms,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase
          .from(_tableName)
          .upsert(payload, onConflict: 'headword,pos');
      onSnack?.call('✅ บันทึกข้อมูลสำเร็จ');
      await refreshData();
      return true;
    } catch (e) {
      debugPrint('Save error: $e');
      onSnack?.call('❌ บันทึกไม่สำเร็จ: $e', isError: true);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> deleteVocab(dynamic id) async {
    await _supabase.from(_tableName).delete().eq('id', id);
    await refreshData();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS (ไม่มี Widget dependency)
  // ─────────────────────────────────────────────────────────────────────────

  static Color cefrColor(String cefr) {
    switch (cefr.toUpperCase()) {
      case 'A1':
        return const Color(0xFF43A047);
      case 'A2':
        return const Color(0xFF66BB6A);
      case 'B1':
        return const Color(0xFF1E88E5);
      case 'B2':
        return const Color(0xFF1565C0);
      case 'C1':
        return const Color(0xFFE53935);
      case 'C2':
        return const Color(0xFF880E4F);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}