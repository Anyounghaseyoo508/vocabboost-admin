import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // สำหรับ kIsWeb
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({super.key});

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  bool _isImporting = false;
  String _statusMessage = "เลือกไฟล์ CSV เพื่อนำเข้าสู่ระบบ";
  final _supabase = Supabase.instance.client;

  Future<void> _pickAndImportCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null) return;

      setState(() {
        _isImporting = true;
        _statusMessage = "กำลังอ่านไฟล์และตรวจสอบความซ้ำซ้อน...";
      });

      List<List<dynamic>> fields = [];

      // รองรับทั้ง Web และ Mobile/Desktop
      if (kIsWeb || result.files.single.bytes != null) {
        final content = utf8.decode(result.files.single.bytes!);
        fields = const CsvToListConverter().convert(content);
      } else {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        fields = const CsvToListConverter().convert(content);
      }

      if (fields.length <= 1)
        throw "ไฟล์ไม่มีข้อมูลหรือไม่มีหัวคอลัมน์ (Header)";

      List<dynamic> header = fields[0]
          .map((e) => e.toString().trim().toLowerCase())
          .toList();

      // ค้นหา Index ของคอลัมน์สำคัญ
      int idxTest = header.indexOf('test_id');
      int idxPart = header.indexOf('part');
      int idxQNo = header.indexOf('question_no');

      if (idxTest == -1 || idxPart == -1 || idxQNo == -1) {
        throw "ไม่พบคอลัมน์บังคับ: test_id, part, question_no";
      }

      List<Map<String, dynamic>> rowsToInsert = [];
      List<String> duplicatedIds = [];

      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        if (row.isEmpty || row.length < 3) continue;

        // สร้าง ID เพื่อเช็คซ้ำ (เช่น 1_P1_Q1)
        String customId = "${row[idxTest]}_P${row[idxPart]}_Q${row[idxQNo]}";

        final existing = await _supabase
            .from('practice_test')
            .select('id')
            .eq('custom_id', customId)
            .maybeSingle();

        if (existing != null) {
          duplicatedIds.add(customId);
          continue;
        }

        // Mapping ข้อมูลตามไฟล์ CSV ที่คุณส่งมา
        rowsToInsert.add({
          'custom_id': customId,
          'test_id': int.tryParse(row[idxTest].toString()) ?? 0,
          'part': int.tryParse(row[idxPart].toString()) ?? 0,
          'question_no': int.tryParse(row[idxQNo].toString()) ?? 0,
          'question_text': _getVal(row, header, 'question_text'),
          'option_a': _getVal(row, header, 'option_a'),
          'option_b': _getVal(row, header, 'option_b'),
          'option_c': _getVal(row, header, 'option_c'),
          'option_d': _getVal(row, header, 'option_d'),
          'correct_answer': _getVal(row, header, 'correct_answer'),
          'explanation': _getVal(row, header, 'explanation'),
          'transcript': _getVal(row, header, 'transcript'),
          'audio_url': _getVal(row, header, 'audio_url'),
          'image_url': _getVal(row, header, 'image_url'),
          'category': _getVal(row, header, 'category'),
          'passage_group_id': _getVal(row, header, 'passage_group_id'),
          // แปลงเป็น Integer (วินาที)
          'start_time':
              int.tryParse(row[header.indexOf('start_time')].toString()) ?? 0,
          'end_time':
              int.tryParse(row[header.indexOf('end_time')].toString()) ?? 0,
        });
      }

      if (rowsToInsert.isNotEmpty) {
        await _supabase.from('practice_test').insert(rowsToInsert);
      }

      setState(() {
        _isImporting = false;
        _statusMessage = "✅ สำเร็จ: นำเข้า ${rowsToInsert.length} รายการ";
        if (duplicatedIds.isNotEmpty) {
          _statusMessage +=
              "\n⚠️ ข้าม ${duplicatedIds.length} รายการเนื่องจาก ID ซ้ำ";
        }
      });
    } catch (e) {
      setState(() {
        _isImporting = false;
        _statusMessage = "❌ ข้อผิดพลาด: $e";
      });
    }
  }

  dynamic _getVal(List<dynamic> row, List<dynamic> header, String colName) {
    int idx = header.indexOf(colName);
    return (idx != -1 && idx < row.length) ? row[idx].toString().trim() : "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CSV Data Importer"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.table_chart, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            if (_isImporting)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _pickAndImportCsv,
                icon: const Icon(Icons.file_upload),
                label: const Text("เลือกไฟล์ CSV"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
              ),
            const Divider(height: 50),
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Future<void> _launchTemplateUrl() async {
    final Uri url = Uri.parse(
      'https://docs.google.com/spreadsheets/d/1-C5x3nawqLoi0NxKW93XYPtFIcPhCiErQvPIOS0Tb8w/edit?usp=sharing',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Widget _buildInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "📖 ขั้นตอนและเทมเพลตสำหรับแอดมิน",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 10),

        // แก้ไขส่วน InkWell ให้เรียกใช้ฟังก์ชัน _launchTemplateUrl
        InkWell(
          onTap: _launchTemplateUrl,
          child: const Text(
            "📍 คลิกที่นี่เพื่อเปิด: Google Sheets Template (ก๊อปปี้ไปใช้ได้เลย)",
            style: TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),

        const SizedBox(height: 15),
        const Text(
          "🕒 สูตรคำนวณวินาทีรวม (สำหรับคอลัมน์ O และ P):",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Text(
            "=(HOUR(เซลล์เวลา)*60) + MINUTE(เซลล์เวลา)\nตัวอย่าง: =(HOUR(O2)*60) + MINUTE(O2) ถ้าเวลาคือ 00:01:43 ผลลัพธ์จะเป็น 103",
            style: TextStyle(fontFamily: 'monospace', color: Colors.blueGrey),
          ),
        ),
        const SizedBox(height: 20),
        Table(
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.5)},
          border: TableBorder.all(color: Colors.grey.shade300),
          children: [
            _buildTableRow(
              "ชื่อคอลัมน์ (Header)",
              "คำอธิบาย / ตัวอย่าง",
              isHeader: true,
            ),
            _buildTableRow(
              "test_id",
              "เลขชุดข้อสอบ (เช่น 1 *ชุดเดียวกันเลข test_id ต้องเหมือนกัน*)",
            ),
            _buildTableRow("part", "พาร์ท 1-7 (เช่น 1)"),
            _buildTableRow("question_no", "ข้อที่ (เช่น 101)"),
            _buildTableRow("question_text", "โจทย์คำถาม"),
            _buildTableRow("option_a", "ตัวเลือก A"),
            _buildTableRow("option_b", "ตัวเลือก B"),
            _buildTableRow("option_c", "ตัวเลือก C"),
            _buildTableRow("option_d", "ตัวเลือก D"),
            _buildTableRow(
              "correct_answer",
              "เฉลย (ใส่เฉพาะตัวอักษร A, B, C หรือ D)",
            ),
            _buildTableRow(
              "category",
              "หมวดหมู่ทักษะ (เช่น Grammar, Tense, Detail)",
            ),
            _buildTableRow("start_time", "เวลาเริ่มเสียง (วินาที) "),
            _buildTableRow("end_time", "เวลาจบเสียง (วินาที) "),
            _buildTableRow("audio_url", "ลิงก์ไฟล์เสียง .mp3"),
            _buildTableRow(
              "image_url",
              "ลิงก์ไฟล์รูปภาพ (สำหรับข้อที่ต้องใช้ภาพ)",
            ),
            _buildTableRow(
              "transcript",
              "บทสคริปต์เสียง และบทความ (สำหรับ Part 1-4)",
            ),
            _buildTableRow("explanation", "คำอธิบายเฉลย"),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String col1, String col2, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey.shade200 : Colors.white,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            col1,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.all(8.0), child: Text(col2)),
      ],
    );
  }
}
