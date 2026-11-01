import 'package:firebase_auth/firebase_auth.dart';

// รวมคำสั่งเกี่ยวกับการ Register / Login / Logout ด้วย Firebase Authentication
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ผู้ใช้ที่ล็อกอินอยู่ตอนนี้ (null = ยังไม่ล็อกอิน)
  static User? get currentUser => _auth.currentUser;

  static Future<void> register(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  // แปลง error code ของ Firebase เป็นข้อความภาษาไทยที่ผู้ใช้อ่านเข้าใจ
  static String errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้สมัครไปแล้ว';
      case 'weak-password':
        return 'รหัสผ่านง่ายเกินไป (อย่างน้อย 6 ตัวอักษร)';
      case 'network-request-failed':
        return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้';
      case 'too-many-requests':
        return 'ลองผิดหลายครั้งเกินไป กรุณารอสักครู่';
      default:
        return 'เกิดข้อผิดพลาด: ${e.message}';
    }
  }
}
