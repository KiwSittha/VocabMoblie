import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// อ่านออกเสียงคำศัพท์ด้วย flutter_tts (ใช้ระบบ Text-to-Speech ของเครื่อง)
// และจำ "ความเร็วเสียง" ที่ผู้ใช้ตั้งไว้ด้วย SharedPreferences (เก็บในเครื่อง)
class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static const String _rateKey = 'speech_rate';

  // อ่านออกเสียงข้อความภาษาอังกฤษ
  static Future<void> speak(String text) async {
    final rate = await getSpeechRate();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  // อ่านความเร็วเสียงที่บันทึกไว้ (ค่าเริ่มต้น 0.5 = ปกติ)
  static Future<double> getSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rateKey) ?? 0.5;
  }

  // บันทึกความเร็วเสียงลงเครื่อง (ปิดแอปแล้วเปิดใหม่ค่ายังอยู่)
  static Future<void> saveSpeechRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, rate);
  }
}
