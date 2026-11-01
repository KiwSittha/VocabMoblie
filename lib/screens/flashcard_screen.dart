import 'dart:math';

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/tts_service.dart';
import '../services/word_service.dart';

// หน้าจอที่ 7: สุ่มทบทวนคำศัพท์ (Flashcard)
// กด "สุ่มคำ" -> แสดงคำแบบสุ่ม -> แตะการ์ดเพื่อดูคำแปล -> ฟังเสียง / ติ๊กว่าจำได้แล้ว
class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final _random = Random();
  bool _onlyLearning = true; // สุ่มเฉพาะคำที่ยังไม่จำ
  String? _currentId; // id ของคำที่กำลังแสดงอยู่ (null = ยังไม่ได้สุ่ม)
  bool _showAnswer = false; // เปิดดูคำแปลแล้วหรือยัง

  // สุ่มคำ 1 คำจากรายการ
  void _pickRandom(List<Word> pool) {
    // ถ้ามีมากกว่า 1 คำ ไม่ให้สุ่มได้คำเดิมซ้ำติดกัน
    final choices =
        pool.length > 1 ? pool.where((w) => w.id != _currentId).toList() : pool;
    final word = choices[_random.nextInt(choices.length)];
    setState(() {
      _currentId = word.id;
      _showAnswer = false; // คำใหม่ ให้ปิดคำแปลไว้ก่อน
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สุ่มทบทวนคำศัพท์')),
      body: StreamBuilder<List<Word>>(
        stream: WordService.getWords(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allWords = snapshot.data!;
          if (allWords.isEmpty) {
            return const Center(child: Text('ยังไม่มีคำศัพท์ให้ทบทวน\nเพิ่มคำก่อนนะ'));
          }

          // pool = คำที่เอามาสุ่มได้
          final pool = _onlyLearning
              ? allWords.where((w) => !w.remembered).toList()
              : allWords;

          // หาคำที่กำลังแสดงจาก allWords (ไม่ใช่ pool)
          // เพื่อให้กด "จำได้แล้ว" แล้วการ์ดยังอยู่ ไม่หายไปทันที
          final current = allWords.where((w) => w.id == _currentId).firstOrNull;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('สุ่มเฉพาะคำที่ยังไม่จำ'),
                  subtitle: Text('มีคำให้สุ่ม ${pool.length} คำ'),
                  value: _onlyLearning,
                  onChanged: (value) => setState(() => _onlyLearning = value),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: current == null
                      ? _buildStartCard(pool.isEmpty)
                      : _buildWordCard(current),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: pool.isEmpty ? null : () => _pickRandom(pool),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.shuffle),
                  label: Text(current == null ? 'สุ่มคำ' : 'สุ่มคำถัดไป'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // การ์ดตอนยังไม่ได้สุ่ม
  Widget _buildStartCard(bool poolIsEmpty) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            poolIsEmpty
                ? 'เก่งมาก! จำได้ครบทุกคำแล้ว 🎉\nปิดตัวกรองด้านบนเพื่อสุ่มคำทั้งหมด'
                : 'กดปุ่ม "สุ่มคำ" ด้านล่างเพื่อเริ่มทบทวน',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  // การ์ดคำศัพท์: แตะเพื่อเปิด/ปิดคำแปล
  Widget _buildWordCard(Word word) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _showAnswer = !_showAnswer),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                word.word,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall,
              ),
              if (word.phonetic.isNotEmpty)
                Text(word.phonetic, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              IconButton.filled(
                iconSize: 32,
                icon: const Icon(Icons.volume_up),
                tooltip: 'ฟังเสียง',
                onPressed: () => TtsService.speak(word.word),
              ),
              const SizedBox(height: 24),
              if (!_showAnswer)
                Text(
                  'แตะการ์ดเพื่อดูคำแปล',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                )
              else ...[
                if (word.thai.isNotEmpty)
                  Text(
                    word.thai,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                if (word.meaning.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(word.meaning, textAlign: TextAlign.center),
                ],
                if (word.example.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '"${word.example}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              // ปุ่มสลับ จำได้แล้ว / ยังไม่จำ (บันทึกลง Firestore ทันที)
              OutlinedButton.icon(
                onPressed: () => WordService.setRemembered(word.id, !word.remembered),
                icon: Icon(
                  word.remembered ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: word.remembered ? Colors.green : null,
                ),
                label: Text(word.remembered ? 'จำได้แล้ว' : 'กดเมื่อจำได้แล้ว'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
