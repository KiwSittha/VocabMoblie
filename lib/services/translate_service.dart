import 'dart:convert';

import 'package:http/http.dart' as http;

// แปลภาษาอังกฤษ -> ภาษาไทย ด้วย REST API ของ MyMemory (https://mymemory.translated.net)
// ใช้ฟรี ไม่ต้องสมัคร (จำกัดประมาณ 5,000 ตัวอักษรต่อวัน)
// ตัวอย่าง URL: https://api.mymemory.translated.net/get?q=schedule&langpair=en|th
//
// MyMemory มีคำแปลให้หลายตัวเลือกใน "matches" (มาจากคลังคำแปลที่คนส่งเข้ามา + เครื่องแปล)
// บางตัวเลือกคุณภาพต่ำ เช่น invoice -> "ใบเสร็จค่าตั๋วโดยสาร" (quality = 0)
// จึงต้องคัดกรองเองแทนการใช้คำตอบแรกเลย
class TranslateService {
  // แปลคำศัพท์เป็นภาษาไทย: คืนค่าคำแปลได้หลายแบบ (ไม่เกิน 3) คั่นด้วย ,
  // เช่น book -> "หนังสือ, จอง" หรือ null ถ้าแปลไม่ได้
  static Future<String?> toThai(String word) async {
    final url = Uri.https('api.mymemory.translated.net', '/get', {
      'q': word,
      'langpair': 'en|th',
    });

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('เซิร์ฟเวอร์ตอบกลับผิดพลาด (${response.statusCode})');
    }
    return parse(response.body);
  }

  // รูปแบบ JSON (ย่อ):
  // { "responseData": { "translatedText": "..." },
  //   "responseStatus": 200,
  //   "matches": [ { "translation": "ใบแจ้งหนี้", "quality": 74, "match": 0.98 }, ... ] }
  static String? parse(String body, {int maxResults = 3}) {
    final Map<String, dynamic> data = jsonDecode(body);

    // MyMemory บอกสถานะใน JSON ด้วย เช่น 429 = ใช้เกินโควตาวันนี้
    if (data['responseStatus'] != 200) {
      throw Exception(data['responseDetails'] ?? 'แปลไม่สำเร็จ');
    }

    final results = <String>[];
    for (final m in data['matches'] ?? []) {
      // quality บางทีเป็นตัวเลข บางทีเป็นข้อความ เช่น "74" จึงแปลงเป็นข้อความก่อน
      final quality = int.tryParse('${m['quality']}') ?? 0;
      final match = double.tryParse('${m['match']}') ?? 0;
      final text = _cleanUp('${m['translation'] ?? ''}');

      if (quality == 0) continue; // ไม่มีใครรับรองคุณภาพ ข้าม
      if (match < 0.85) continue; // ต้นฉบับไม่ตรงกับคำที่ค้นหา ข้าม
      if (!_hasThai(text)) continue; // ไม่ได้แปลเป็นภาษาไทย เช่น "Deadline" ข้าม
      if (results.contains(text)) continue; // ซ้ำกับที่มีแล้ว ข้าม

      results.add(text);
      if (results.length == maxResults) break;
    }

    // ถ้าคัดแล้วไม่เหลือเลย ใช้คำตอบหลักของ API แทน
    if (results.isEmpty) {
      final text = _cleanUp('${data['responseData']?['translatedText'] ?? ''}');
      return _hasThai(text) ? text : null;
    }
    return results.join(', ');
  }

  // มีตัวอักษรไทยอยู่ในข้อความหรือไม่ (ตัวอักษรไทยอยู่ในช่วง Unicode U+0E00 - U+0E7F)
  static bool _hasThai(String text) => RegExp(r'[฀-๿]').hasMatch(text);

  // เก็บกวาดคำแปล: ตัดช่องว่างหัวท้าย และแก้คำที่ซ้ำติดกัน เช่น "วิ่งวิ่งวิ่ง" -> "วิ่ง"
  static String _cleanUp(String text) {
    final trimmed = text.trim();
    final repeated = RegExp(r'^(.+?)\1+$').firstMatch(trimmed);
    return repeated != null ? repeated.group(1)! : trimmed;
  }
}
