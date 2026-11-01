import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/tts_service.dart';
import '../services/word_service.dart';
import 'word_form_screen.dart';

// หน้าจอที่ 5: รายละเอียดคำศัพท์ + ปุ่มฟังเสียง / แก้ไข / ลบ
class WordDetailScreen extends StatelessWidget {
  final String wordId;

  const WordDetailScreen({super.key, required this.wordId});

  // ถามยืนยันก่อนลบ แล้วค่อยลบ (DELETE)
  Future<void> _confirmDelete(BuildContext context, Word word) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบคำศัพท์'),
        content: Text('ต้องการลบคำว่า "${word.word}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;
    Navigator.pop(context); // ปิดหน้ารายละเอียดก่อน แล้วค่อยลบ
    await WordService.deleteWord(word.id);
  }

  @override
  Widget build(BuildContext context) {
    // ฟังข้อมูลคำนี้แบบ realtime: แก้ไขเสร็จกลับมาหน้านี้จะเห็นข้อมูลใหม่ทันที
    return StreamBuilder<Word?>(
      stream: WordService.getWord(wordId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final word = snapshot.data;
        if (word == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('ไม่พบคำศัพท์นี้')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('รายละเอียด'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'แก้ไข',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WordFormScreen(word: word)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'ลบ',
                onPressed: () => _confirmDelete(context, word),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      word.word,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  IconButton.filled(
                    iconSize: 32,
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'ฟังเสียง',
                    onPressed: () => TtsService.speak(word.word),
                  ),
                ],
              ),
              if (word.phonetic.isNotEmpty)
                Text(word.phonetic, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              if (word.thai.isNotEmpty) ...[
                _section(context, 'คำแปลภาษาไทย', word.thai),
                const SizedBox(height: 16),
              ],
              if (word.meaning.isNotEmpty)
                _section(context, 'ความหมาย (ภาษาอังกฤษ)', word.meaning),
              if (word.example.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _section(context, 'ประโยคตัวอย่าง', word.example)),
                    IconButton(
                      icon: const Icon(Icons.record_voice_over),
                      tooltip: 'ฟังประโยค',
                      onPressed: () => TtsService.speak(word.example),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('จำได้แล้ว'),
                value: word.remembered,
                onChanged: (value) => WordService.setRemembered(word.id, value),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
