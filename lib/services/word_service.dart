import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/word.dart';

// รวมคำสั่ง CRUD ของคำศัพท์กับ Cloud Firestore
//
// โครงสร้าง Database:
//   users (collection)
//     └─ {uid} (document ของผู้ใช้แต่ละคน)
//          └─ words (collection)
//               └─ {wordId}: word, phonetic, meaning, example, remembered, createdAt
//
// แยกคำศัพท์ตาม uid ทำให้ผู้ใช้แต่ละคนเห็นเฉพาะคำของตัวเอง
class WordService {
  // collection "words" ของผู้ใช้ที่ล็อกอินอยู่
  static CollectionReference<Map<String, dynamic>> get _words {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('words');
  }

  // CREATE - เพิ่มคำใหม่
  static Future<void> addWord(Word word) async {
    await _words.add({
      ...word.toMap(),
      'createdAt': FieldValue.serverTimestamp(), // เวลาที่บันทึก (ใช้เรียงลำดับ)
    });
  }

  // READ - อ่านคำทั้งหมด แบบ Stream (ข้อมูลเปลี่ยนเมื่อไหร่ หน้าจอจะอัปเดตเอง)
  static Stream<List<Word>> getWords() {
    return _words
        .orderBy('createdAt', descending: true) // คำล่าสุดขึ้นก่อน
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Word.fromDoc).toList());
  }

  // READ - อ่านคำเดียว (ใช้ในหน้ารายละเอียด)
  static Stream<Word?> getWord(String id) {
    return _words.doc(id).snapshots().map(
          (doc) => doc.exists ? Word.fromDoc(doc) : null,
        );
  }

  // UPDATE - แก้ไขคำ
  static Future<void> updateWord(Word word) async {
    await _words.doc(word.id).update(word.toMap());
  }

  // UPDATE - สลับสถานะ จำได้แล้ว / ยังไม่จำ
  static Future<void> setRemembered(String id, bool remembered) async {
    await _words.doc(id).update({'remembered': remembered});
  }

  // DELETE - ลบคำ
  static Future<void> deleteWord(String id) async {
    await _words.doc(id).delete();
  }
}
