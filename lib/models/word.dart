import 'package:cloud_firestore/cloud_firestore.dart';

// Model = แม่แบบของข้อมูล "คำศัพท์" 1 คำ
// ใน Firestore เก็บที่: users/{uid}/words/{wordId}
class Word {
  final String id; // id ของเอกสารใน Firestore (คำใหม่ที่ยังไม่บันทึกจะเป็น '')
  final String word; // คำศัพท์ เช่น "apple"
  final String phonetic; // คำอ่าน เช่น "/ˈæp.əl/"
  final String thai; // คำแปลภาษาไทย เช่น "แอปเปิล"
  final String meaning; // ความหมายภาษาอังกฤษ
  final String example; // ประโยคตัวอย่าง
  final bool remembered; // จำได้แล้วหรือยัง

  Word({
    this.id = '',
    required this.word,
    this.phonetic = '',
    this.thai = '',
    required this.meaning,
    this.example = '',
    this.remembered = false,
  });

  // แปลงเอกสารจาก Firestore -> Word
  factory Word.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Word(
      id: doc.id,
      word: data['word'] ?? '',
      phonetic: data['phonetic'] ?? '',
      thai: data['thai'] ?? '', // คำเก่าที่บันทึกก่อนมีช่องนี้จะได้ค่าว่าง
      meaning: data['meaning'] ?? '',
      example: data['example'] ?? '',
      remembered: data['remembered'] ?? false,
    );
  }

  // แปลง Word -> Map เพื่อบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'phonetic': phonetic,
      'thai': thai,
      'meaning': meaning,
      'example': example,
      'remembered': remembered,
    };
  }
}
