import 'dart:convert';

import 'package:http/http.dart' as http;

// ผลลัพธ์ที่ได้จาก Dictionary API
class DictionaryResult {
  final String phonetic;
  final String meaning;
  final String example;

  DictionaryResult({
    required this.phonetic,
    required this.meaning,
    required this.example,
  });
}

// เรียก REST API ของ Free Dictionary (https://dictionaryapi.dev)
// ตัวอย่าง URL: https://api.dictionaryapi.dev/api/v2/entries/en/hello
class DictionaryService {
  static const int _maxAttempts = 3;

  // ค้นหาคำ -> คืนค่า DictionaryResult หรือ null ถ้าไม่พบคำนี้
  //
  // API ฟรีตัวนี้ไม่เสถียร: บางครั้งตอบ 404 (ไม่พบคำ) ทั้งที่มีคำนั้นอยู่จริง
  // เรียกซ้ำอีกทีก็เจอ หรือตอบ 429 เมื่อเรียกถี่เกินไป
  // จึงลองใหม่อัตโนมัติสูงสุด 3 ครั้ง ก่อนจะสรุปว่าไม่พบคำ
  static Future<DictionaryResult?> lookup(String word) async {
    final url = Uri.parse(
      'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}',
    );

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final isLastAttempt = attempt == _maxAttempts;

      http.Response response;
      try {
        // await = รอจนกว่าเซิร์ฟเวอร์จะตอบกลับ (Asynchronous) ถ้าเกิน 10 วินาทีให้ error
        response = await http.get(url).timeout(const Duration(seconds: 10));
      } catch (e) {
        // ต่อเน็ตไม่ได้ / หมดเวลา: ถ้ายังไม่ครบ 3 ครั้งให้รอแล้วลองใหม่
        if (isLastAttempt) rethrow;
        await Future.delayed(Duration(seconds: attempt));
        continue;
      }

      if (response.statusCode == 200) {
        return parse(response.body); // สำเร็จ
      }
      if (isLastAttempt) {
        if (response.statusCode == 404) {
          return null; // ลองครบ 3 ครั้งแล้วยังได้ 404 = ไม่พบคำนี้จริง ๆ
        }
        throw Exception('เซิร์ฟเวอร์ตอบกลับผิดพลาด (${response.statusCode})');
      }
      // รอ 1 วินาที แล้ว 2 วินาที ก่อนลองใหม่ (ให้เซิร์ฟเวอร์ได้พัก)
      await Future.delayed(Duration(seconds: attempt));
    }
    return null;
  }

  // แปลง JSON ที่ได้จาก API ให้เหลือเฉพาะข้อมูลที่แอปใช้
  //
  // รูปแบบ JSON (ย่อ):
  // [ { "word": "hello",
  //     "phonetic": "/həˈləʊ/",
  //     "meanings": [ { "partOfSpeech": "noun",
  //                     "definitions": [ { "definition": "...", "example": "..." } ] } ] } ]
  static DictionaryResult? parse(String body) {
    final List<dynamic> entries = jsonDecode(body);
    if (entries.isEmpty) return null;

    final Map<String, dynamic> entry = entries[0];
    final List<dynamic> meanings = entry['meanings'] ?? [];
    if (meanings.isEmpty) return null;

    // คำอ่าน: ใช้ "phonetic" ถ้ามี ถ้าไม่มีให้หาใน "phonetics"
    String phonetic = entry['phonetic'] ?? '';
    if (phonetic.isEmpty) {
      for (final p in entry['phonetics'] ?? []) {
        if ((p['text'] ?? '').toString().isNotEmpty) {
          phonetic = p['text'];
          break;
        }
      }
    }

    // ความหมาย: เอาความหมายแรกของคำ พร้อมชนิดของคำ เช่น "(noun) a round fruit..."
    final first = meanings[0];
    final String partOfSpeech = first['partOfSpeech'] ?? '';
    final String definition = first['definitions'][0]['definition'] ?? '';
    final meaning = partOfSpeech.isEmpty ? definition : '($partOfSpeech) $definition';

    // ประโยคตัวอย่าง: หาอันแรกที่มี example
    String example = '';
    for (final m in meanings) {
      for (final d in m['definitions'] ?? []) {
        if ((d['example'] ?? '').toString().isNotEmpty) {
          example = d['example'];
          break;
        }
      }
      if (example.isNotEmpty) break;
    }

    return DictionaryResult(phonetic: phonetic, meaning: meaning, example: example);
  }
}
