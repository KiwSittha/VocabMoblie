import 'package:flutter_test/flutter_test.dart';

import 'package:moblie_app/services/dictionary_service.dart';
import 'package:moblie_app/services/translate_service.dart';

// ทดสอบว่าแปลง JSON จาก API ได้ถูกต้อง (ไม่ต้องต่ออินเทอร์เน็ต)
// รันด้วยคำสั่ง: flutter test
void main() {
  test('parse dictionary JSON', () {
    const body = '''
[
  {
    "word": "schedule",
    "phonetic": "",
    "phonetics": [ { "text": "" }, { "text": "/ˈʃɛdjuːl/" } ],
    "meanings": [
      {
        "partOfSpeech": "noun",
        "definitions": [ { "definition": "A time-based plan of events." } ]
      },
      {
        "partOfSpeech": "verb",
        "definitions": [ { "definition": "To plan.", "example": "We scheduled the meeting for Monday." } ]
      }
    ]
  }
]
''';

    final result = DictionaryService.parse(body)!;

    expect(result.phonetic, '/ˈʃɛdjuːl/');
    expect(result.meaning, '(noun) A time-based plan of events.');
    expect(result.example, 'We scheduled the meeting for Monday.');
  });

  test('parse translate JSON', () {
    const body =
        '{"responseData":{"translatedText":"กำหนดการ","match":1},"responseStatus":200}';
    expect(TranslateService.parse(body), 'กำหนดการ');
  });

  // ใช้ข้อมูลจริงที่ API ตอบมาสำหรับคำว่า invoice / run
  test('translate skips low-quality and repeated answers', () {
    const invoice = '''
{"responseData":{"translatedText":"ใบเสร็จค่าตั๋วโดยสาร"},"responseStatus":200,
 "matches":[
   {"translation":"ใบเสร็จค่าตั๋วโดยสาร","quality":"0","match":1},
   {"translation":"ใบแจ้งหนี้","quality":74,"match":0.98},
   {"translation":"Invoice","quality":74,"match":0.97},
   {"translation":"ใบแจ้งหนี้","quality":"74","match":0.97}
 ]}''';
    expect(TranslateService.parse(invoice), 'ใบแจ้งหนี้');

    const run = '''
{"responseData":{"translatedText":"ประมวลผล"},"responseStatus":200,
 "matches":[
   {"translation":"ประมวลผล","quality":"0","match":1},
   {"translation":"วิ่งวิ่งวิ่ง","quality":"74","match":1}
 ]}''';
    expect(TranslateService.parse(run), 'วิ่ง');
  });

  test('translate quota error throws', () {
    const body =
        '{"responseData":{"translatedText":""},"responseStatus":429,"responseDetails":"QUOTA EXCEEDED"}';
    expect(() => TranslateService.parse(body), throwsException);
  });
}
