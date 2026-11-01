import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/tts_service.dart';
import '../services/word_service.dart';
import 'flashcard_screen.dart';
import 'profile_screen.dart';
import 'word_detail_screen.dart';
import 'word_form_screen.dart';

// หน้าจอที่ 3: รายการคำศัพท์ทั้งหมด (READ)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ตัวกรอง: 'all' = ทั้งหมด, 'learning' = ยังไม่จำ, 'remembered' = จำได้แล้ว
  String _filter = 'all';

  List<Word> _applyFilter(List<Word> words) {
    if (_filter == 'learning') {
      return words.where((w) => !w.remembered).toList();
    }
    if (_filter == 'remembered') {
      return words.where((w) => w.remembered).toList();
    }
    return words;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocab Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'สุ่มทบทวน',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FlashcardScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'โปรไฟล์',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มคำ'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WordFormScreen()),
          );
        },
      ),
      // StreamBuilder = ฟังข้อมูลจาก Firestore แบบ realtime
      // เพิ่ม/แก้/ลบคำที่ไหน รายการตรงนี้อัปเดตเองทันที
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
          final rememberedCount = allWords.where((w) => w.remembered).length;
          final words = _applyFilter(allWords);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'จำได้แล้ว $rememberedCount / ${allWords.length} คำ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('ทั้งหมด')),
                    ButtonSegment(value: 'learning', label: Text('ยังไม่จำ')),
                    ButtonSegment(value: 'remembered', label: Text('จำได้แล้ว')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selected) {
                    setState(() => _filter = selected.first);
                  },
                ),
              ),
              Expanded(
                child: words.isEmpty
                    ? const Center(
                        child: Text(
                          'ยังไม่มีคำศัพท์\nกดปุ่ม "เพิ่มคำ" เพื่อเริ่มต้น',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: words.length,
                        itemBuilder: (context, index) => _buildWordCard(words[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordCard(Word word) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        // ปุ่มลำโพง: กดแล้วอ่านออกเสียงคำ
        leading: IconButton(
          icon: const Icon(Icons.volume_up),
          tooltip: 'ฟังเสียง',
          onPressed: () => TtsService.speak(word.word),
        ),
        title: Text(
          word.phonetic.isEmpty ? word.word : '${word.word}  ${word.phonetic}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        // แสดงคำแปลไทยก่อน (ถ้ามี) แล้วตามด้วยความหมายอังกฤษ
        subtitle: Text(
          word.thai.isEmpty ? word.meaning : '${word.thai}\n${word.meaning}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // ปุ่มติ๊ก: สลับ จำได้แล้ว / ยังไม่จำ
        trailing: IconButton(
          icon: Icon(
            word.remembered ? Icons.check_circle : Icons.radio_button_unchecked,
            color: word.remembered ? Colors.green : null,
          ),
          tooltip: word.remembered ? 'จำได้แล้ว' : 'ยังไม่จำ',
          onPressed: () => WordService.setRemembered(word.id, !word.remembered),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WordDetailScreen(wordId: word.id)),
          );
        },
      ),
    );
  }
}
