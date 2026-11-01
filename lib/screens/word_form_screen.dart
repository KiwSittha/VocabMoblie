import 'dart:math';

import 'package:flutter/material.dart';

import '../data/toeic_words.dart';
import '../models/word.dart';
import '../services/dictionary_service.dart';
import '../services/translate_service.dart';
import '../services/tts_service.dart';
import '../services/word_service.dart';

// หน้าจอที่ 4: ฟอร์มเพิ่มคำใหม่ (CREATE) และแก้ไขคำ (UPDATE)
// - ไม่ส่ง word มา  = โหมดเพิ่มคำใหม่
// - ส่ง word มาด้วย = โหมดแก้ไข
class WordFormScreen extends StatefulWidget {
  final Word? word;

  const WordFormScreen({super.key, this.word});

  @override
  State<WordFormScreen> createState() => _WordFormScreenState();
}

class _WordFormScreenState extends State<WordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _phoneticController = TextEditingController();
  final _thaiController = TextEditingController();
  final _meaningController = TextEditingController();
  final _exampleController = TextEditingController();
  bool _remembered = false;
  bool _searching = false; // กำลังเรียก API อยู่หรือไม่
  bool _saving = false; // กำลังบันทึกลง Firestore อยู่หรือไม่

  bool get _isEdit => widget.word != null;

  @override
  void initState() {
    super.initState();
    // โหมดแก้ไข: ใส่ข้อมูลเดิมลงในช่องกรอก
    final word = widget.word;
    if (word != null) {
      _wordController.text = word.word;
      _phoneticController.text = word.phonetic;
      _thaiController.text = word.thai;
      _meaningController.text = word.meaning;
      _exampleController.text = word.example;
      _remembered = word.remembered;
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _phoneticController.dispose();
    _thaiController.dispose();
    _meaningController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  // ตรวจว่าคำศัพท์เป็นภาษาอังกฤษ (ตัวอักษร a-z, เว้นวรรค, - และ ')
  String? _validateWord(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอกคำศัพท์';
    }
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(value.trim())) {
      return 'กรอกได้เฉพาะตัวอักษรภาษาอังกฤษ';
    }
    return null;
  }

  // ดึงความหมายจาก Dictionary API และคำแปลไทยจาก Translate API แล้วเติมลงฟอร์มให้อัตโนมัติ
  Future<void> _lookup() async {
    final error = _validateWord(_wordController.text);
    if (error != null) {
      _showMessage(error);
      return;
    }
    FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ด
    final text = _wordController.text.trim();

    setState(() => _searching = true);

    // 1) คำอ่าน + ความหมายภาษาอังกฤษ + ประโยคตัวอย่าง จาก Dictionary API
    try {
      final result = await DictionaryService.lookup(text);
      if (!mounted) return;
      if (result == null) {
        _showMessage('ไม่พบคำนี้ในพจนานุกรม สามารถกรอกความหมายเองได้');
      } else {
        _phoneticController.text = result.phonetic;
        _meaningController.text = result.meaning;
        _exampleController.text = result.example;
      }
    } catch (e) {
      _showMessage('ดึงความหมายไม่สำเร็จ ตรวจสอบอินเทอร์เน็ต');
    }

    // 2) คำแปลภาษาไทย จาก Translate API
    // แยก try คนละอัน: ถ้า API หนึ่งล่ม อีก API ยังเติมข้อมูลให้ได้
    try {
      final thai = await TranslateService.toThai(text);
      if (!mounted) return;
      if (thai != null) _thaiController.text = thai;
    } catch (e) {
      _showMessage('แปลภาษาไทยไม่สำเร็จ สามารถกรอกเองได้');
    }

    if (mounted) setState(() => _searching = false);
  }

  // สุ่มคำจากรายการคำศัพท์ TOEIC (ข้ามคำที่บันทึกไว้แล้ว) แล้วดึงความหมายให้อัตโนมัติ
  Future<void> _randomWord() async {
    setState(() => _searching = true);

    // อ่านคำที่ผู้ใช้บันทึกไว้แล้ว 1 ครั้ง (.first = เอาแค่ข้อมูลชุดแรกจาก Stream)
    Set<String> savedWords = {};
    try {
      final saved = await WordService.getWords().first;
      savedWords = saved.map((w) => w.word).toSet();
    } catch (e) {
      // อ่านไม่ได้ก็ไม่เป็นไร สุ่มจากทุกคำแทน
    }
    if (!mounted) return;

    final choices = toeicWords.where((w) => !savedWords.contains(w)).toList();
    if (choices.isEmpty) {
      _showMessage('บันทึกคำในรายการสุ่มครบทุกคำแล้ว เก่งมาก!');
      setState(() => _searching = false);
      return;
    }

    // ล้างข้อมูลคำเก่าในฟอร์ม แล้วใส่คำที่สุ่มได้
    _wordController.text = choices[Random().nextInt(choices.length)];
    _phoneticController.clear();
    _thaiController.clear();
    _meaningController.clear();
    _exampleController.clear();

    await _lookup(); // ดึงความหมาย + คำแปลไทย เหมือนกดปุ่มค้นหา
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final word = Word(
      id: widget.word?.id ?? '',
      word: _wordController.text.trim().toLowerCase(),
      phonetic: _phoneticController.text.trim(),
      thai: _thaiController.text.trim(),
      meaning: _meaningController.text.trim(),
      example: _exampleController.text.trim(),
      remembered: _remembered,
    );

    try {
      if (_isEdit) {
        await WordService.updateWord(word);
      } else {
        await WordService.addWord(word);
      }
      if (!mounted) return;
      _showMessage(_isEdit ? 'แก้ไขคำเรียบร้อย' : 'บันทึกคำเรียบร้อย');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'แก้ไขคำศัพท์' : 'เพิ่มคำศัพท์')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _wordController,
                decoration: InputDecoration(
                  labelText: 'คำศัพท์ภาษาอังกฤษ *',
                  hintText: 'เช่น schedule',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'ฟังเสียง',
                    onPressed: () {
                      if (_wordController.text.trim().isNotEmpty) {
                        TtsService.speak(_wordController.text.trim());
                      }
                    },
                  ),
                ),
                validator: _validateWord,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _lookup(), // กด Enter = ค้นหา
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _searching ? null : _lookup,
                icon: _searching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_searching ? 'กำลังค้นหา...' : 'ดึงความหมาย + คำแปลไทย'),
              ),
              // ปุ่มสุ่มคำ แสดงเฉพาะตอนเพิ่มคำใหม่ (ตอนแก้ไขไม่ต้องสุ่ม)
              if (!_isEdit)
                TextButton.icon(
                  onPressed: _searching ? null : _randomWord,
                  icon: const Icon(Icons.shuffle),
                  label: const Text('สุ่มคำศัพท์ TOEIC'),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneticController,
                decoration: const InputDecoration(
                  labelText: 'คำอ่าน',
                  hintText: 'เช่น /ˈʃedʒ.uːl/',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _thaiController,
                decoration: const InputDecoration(
                  labelText: 'คำแปลภาษาไทย',
                  hintText: 'เช่น กำหนดการ, ตารางเวลา',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _meaningController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ความหมาย (ภาษาอังกฤษ)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                // ต้องมีคำแปลไทย หรือ ความหมายอังกฤษ อย่างน้อย 1 ช่อง
                validator: (value) {
                  if ((value == null || value.trim().isEmpty) &&
                      _thaiController.text.trim().isEmpty) {
                    return 'กรุณากรอกคำแปลไทยหรือความหมายอย่างน้อย 1 ช่อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _exampleController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ประโยคตัวอย่าง',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('จำได้แล้ว'),
                value: _remembered,
                onChanged: (value) => setState(() => _remembered = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
