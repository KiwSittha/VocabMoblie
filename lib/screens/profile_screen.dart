import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/auth_service.dart';
import '../services/tts_service.dart';
import '../services/word_service.dart';

// หน้าจอที่ 6: โปรไฟล์ สถิติการท่องศัพท์ ตั้งค่าความเร็วเสียง และ Logout
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double _speechRate = 0.5;

  @override
  void initState() {
    super.initState();
    _loadSpeechRate();
  }

  // โหลดค่าความเร็วเสียงที่เคยบันทึกไว้ใน SharedPreferences
  Future<void> _loadSpeechRate() async {
    final rate = await TtsService.getSpeechRate();
    if (mounted) setState(() => _speechRate = rate);
  }

  Future<void> _logout() async {
    // ปิดทุกหน้าที่ซ้อนอยู่ กลับไปหน้าแรก (AuthGate) แล้วค่อย logout
    Navigator.popUntil(context, (route) => route.isFirst);
    await AuthService.logout();
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.currentUser?.email ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 8),
          Text(email, textAlign: TextAlign.center),
          const SizedBox(height: 24),

          // สถิติ: นับจำนวนคำจาก Firestore
          StreamBuilder<List<Word>>(
            stream: WordService.getWords(),
            builder: (context, snapshot) {
              final words = snapshot.data ?? [];
              final remembered = words.where((w) => w.remembered).length;
              return Row(
                children: [
                  _statCard('คำทั้งหมด', words.length, Colors.indigo),
                  _statCard('จำได้แล้ว', remembered, Colors.green),
                  _statCard('ยังไม่จำ', words.length - remembered, Colors.orange),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ตั้งค่าความเร็วเสียง (บันทึกด้วย SharedPreferences)
          Text('ความเร็วเสียงอ่าน', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: _speechRate,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            label: _speechRate.toStringAsFixed(1),
            onChanged: (value) => setState(() => _speechRate = value),
            onChangeEnd: (value) => TtsService.saveSpeechRate(value),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.volume_up),
              label: const Text('ทดสอบเสียง'),
              onPressed: () => TtsService.speak('Practice makes perfect'),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
