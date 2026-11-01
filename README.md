# Vocab Book — สมุดคำศัพท์ภาษาอังกฤษ

แอปสำหรับนิสิตที่เตรียมสอบ TOEIC หรือเรียนภาษาอังกฤษ ใช้จดคำศัพท์ แอปจะดึงความหมายและประโยคตัวอย่างให้อัตโนมัติ
กดฟังเสียงอ่านได้ และติ๊กว่าคำไหน "จำได้แล้ว"

**Main Workflow:** Login → พิมพ์คำ → แอปดึงความหมาย → Save → ดูรายการ → กดฟังเสียง → แก้ไข/ลบ

---

## 1. ขั้นตอนตั้งค่า Firebase (ทำครั้งเดียว)

> ถ้ายังไม่ทำขั้นตอนนี้ แอปจะ error ว่า "ยังไม่ได้ตั้งค่า Firebase"

1. เข้า <https://console.firebase.google.com> → **Add project** → ตั้งชื่อ เช่น `vocab-book`
2. เมนู **Build → Authentication** → Get started → แท็บ Sign-in method → เปิด **Email/Password**
3. เมนู **Build → Firestore Database** → Create database → เลือก location (เช่น `asia-southeast1`) → Start in **production mode**
4. ในหน้า Firestore แท็บ **Rules** วางกฎนี้แล้วกด Publish (ให้ผู้ใช้เห็นเฉพาะคำของตัวเอง):

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/words/{wordId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

5. ติดตั้งเครื่องมือ (ครั้งเดียวในเครื่อง):

   ```bash
   npm install -g firebase-tools
   ```

   ```bash
   firebase login
   ```

   ```bash
   dart pub global activate flutterfire_cli
   ```

6. ในโฟลเดอร์โปรเจกต์นี้ รัน แล้วเลือกโปรเจกต์ที่สร้างไว้ และเลือก platform **android**:

   ```bash
   flutterfire configure
   ```

   คำสั่งนี้จะสร้าง `lib/firebase_options.dart` (ทับไฟล์ชั่วคราว) และ `android/app/google-services.json` ให้อัตโนมัติ

## 2. รันแอป

เปิด Android Emulator แล้วรัน:

```bash
flutter run
```

> ถ้ากดฟังเสียงแล้วเงียบ: ใน emulator ไปที่ Settings → System → Languages → Text-to-speech output
> ตรวจว่ามี Google TTS และลองกด Play ดูก่อน และอย่าลืมเปิดเสียง emulator

---

## 3. โครงสร้างไฟล์

```
lib/
├── main.dart                    เริ่มแอป + AuthGate (เลือกหน้า Login หรือ Home ตามสถานะล็อกอิน)
├── firebase_options.dart        ค่าตั้งค่า Firebase (สร้างโดย flutterfire configure)
├── data/
│   └── toeic_words.dart         รายการคำศัพท์ TOEIC ~80 คำ ใช้กับปุ่มสุ่มคำในหน้าเพิ่มคำ
├── models/
│   └── word.dart                แม่แบบข้อมูลคำศัพท์ + แปลงไป/กลับ Firestore
├── services/                    "ส่วนทำงานเบื้องหลัง" แยกจากหน้าจอ
│   ├── auth_service.dart        Register / Login / Logout (Firebase Auth)
│   ├── word_service.dart        CRUD คำศัพท์ (Cloud Firestore)
│   ├── dictionary_service.dart  เรียก REST API dictionaryapi.dev (ความหมายอังกฤษ)
│   ├── translate_service.dart   เรียก REST API MyMemory (แปลเป็นภาษาไทย)
│   └── tts_service.dart         อ่านออกเสียง (flutter_tts) + จำความเร็วเสียง (SharedPreferences)
└── screens/                     หน้าจอทั้ง 7 หน้า
    ├── login_screen.dart        1. เข้าสู่ระบบ
    ├── register_screen.dart     2. สมัครสมาชิก
    ├── home_screen.dart         3. รายการคำศัพท์ + ตัวกรอง
    ├── word_form_screen.dart    4. เพิ่ม / แก้ไขคำ (ดึงความหมายจาก API)
    ├── word_detail_screen.dart  5. รายละเอียดคำ + ฟังเสียง / แก้ไข / ลบ
    ├── profile_screen.dart      6. โปรไฟล์ สถิติ ตั้งค่าเสียง Logout
    └── flashcard_screen.dart    7. สุ่มทบทวนคำศัพท์ (Flashcard)
```

**แนวคิด:** หน้าจอ (screens) ทำหน้าที่แสดงผลและรับข้อมูลจากผู้ใช้ ส่วน services ทำหน้าที่คุยกับ Firebase / API
หน้าจอจึงแค่เรียก เช่น `WordService.addWord(word)` โดยไม่ต้องรู้รายละเอียดของ Firestore

### Screen Flow

```
Login ──(สมัคร)──> Register
  │
  ▼ (ล็อกอินสำเร็จ)
Home (รายการคำ) ──> Profile ──> Logout ──> Login
  │      └──(ปุ่มสุ่ม)──> Flashcard (สุ่มคำ → แตะดูคำแปล → ฟังเสียง → ติ๊กจำได้แล้ว)
  │         │
  │(+เพิ่มคำ) │(แตะคำ)
  ▼         ▼
Word Form   Word Detail ──(แก้ไข)──> Word Form
                │
                └──(ลบ)──> กลับ Home
```

### โครงสร้าง Database (Cloud Firestore)

```
users/{uid}/words/{wordId}
    word:       "schedule"
    phonetic:   "/ˈʃɛdjuːl/"
    thai:       "กำหนดการ"
    meaning:    "(noun) A time-based plan of events."
    example:    "We scheduled the meeting for Monday."
    remembered: false
    createdAt:  (เวลาที่บันทึก)
```

---

## 4. เทียบกับข้อกำหนดของโครงงาน (Checklist)

| ข้อกำหนด | ทำที่ไหนในแอป |
|---|---|
| อย่างน้อย 4 Screens | มี 7 หน้า (ดูหัวข้อ 3) |
| Navigation | `Navigator.push` / `Navigator.pop` ระหว่างหน้า, AuthGate สลับหน้า Login/Home อัตโนมัติ |
| Form + Validation | Login, Register (อีเมลต้องมี @, รหัส ≥ 6 ตัว, ยืนยันรหัสตรงกัน), Word Form (คำต้องเป็นภาษาอังกฤษ, ต้องมีความหมาย) |
| User Authentication | Firebase Auth: Register / Login / Logout, ข้อมูลแยกตามผู้ใช้ (`users/{uid}`) |
| Firebase Database | Cloud Firestore |
| CRUD | **C** `addWord` · **R** `getWords`, `getWord` · **U** `updateWord`, `setRemembered` · **D** `deleteWord` (ใน `word_service.dart`) |
| Asynchronous Operations | `async/await` กับ Firebase และ HTTP, `StreamBuilder` ฟังข้อมูล realtime, แสดง loading ระหว่างรอ |
| Mobile/External Features ≥ 2 | 1) **REST API** dictionaryapi.dev ดึงความหมาย + MyMemory แปลเป็นไทย 2) **flutter_tts** อ่านออกเสียง (Device Feature) 3) **SharedPreferences** จำความเร็วเสียง |
| Main Workflow | Login → พิมพ์คำ → ดึงความหมาย → Save → ดูรายการ → ฟังเสียง → แก้ไข/ลบ |

---

## 5. เตรียมตอบคำถามตอนนำเสนอ

**ทำไมเลือก Firestore?** เก็บข้อมูลบน Cloud ใช้กับ Firebase Auth ได้ง่าย และมี `snapshots()` ที่ส่งข้อมูลใหม่มาอัตโนมัติ
หน้าจอจึงอัปเดตเองเมื่อเพิ่ม/แก้/ลบ

**ทำไมเก็บที่ `users/{uid}/words`?** แยกคำศัพท์ตามผู้ใช้ แต่ละคนเห็นแค่คำของตัวเอง และเขียน Security Rules ได้ง่าย

**Asynchronous คืออะไรในแอปนี้?** งานที่ต้องรอ เช่น ล็อกอิน บันทึกข้อมูล เรียก API ใช้ `await` รอผล
ระหว่างรอแอปไม่ค้าง และแสดงวงกลมหมุน (`CircularProgressIndicator`)

**REST API ทำงานอย่างไร?** `DictionaryService.lookup()` ส่ง HTTP GET ไปที่
`https://api.dictionaryapi.dev/api/v2/entries/en/<คำ>` ได้ JSON กลับมา แล้ว `parse()` ดึงคำอ่าน ความหมายแรก และประโยคตัวอย่าง
ถ้าได้ 404 แปลว่าไม่พบคำ แอปจะบอกผู้ใช้ให้กรอกเอง

**ทำไมต้องลองเรียก API ซ้ำ (Retry)?** API ฟรีตัวนี้ไม่เสถียร บางครั้งตอบ 404 ทั้งที่มีคำนั้นจริง หรือตอบ 429 เมื่อเรียกถี่
`lookup()` จึงลองใหม่สูงสุด 3 ครั้ง โดยรอ 1 และ 2 วินาทีระหว่างครั้ง ถ้าครบ 3 ครั้งยังได้ 404 จึงสรุปว่าไม่พบคำ

**คำแปลภาษาไทยมาจากไหน?** dictionaryapi.dev มีแต่ภาษาอังกฤษ จึงเรียกอีก API คือ `TranslateService.toThai()` ส่ง GET ไปที่
`https://api.mymemory.translated.net/get?q=<คำ>&langpair=en|th` (ฟรี ไม่ต้องใช้ key)
MyMemory ให้คำแปลหลายตัวเลือกใน `matches` บางตัวคุณภาพต่ำ แอปจึงคัดกรองเองใน `parse()`:
ข้ามตัวที่ `quality = 0`, ตัวที่ต้นฉบับไม่ตรงกับคำ, ตัวที่ไม่มีตัวอักษรไทย และตัวที่ซ้ำ แล้วเก็บไว้ไม่เกิน 3 แบบ
เช่น book → "หนังสือ, จอง"
เรียก 2 API ใน `try` คนละอัน ถ้าอันหนึ่งล่ม อีกอันยังเติมข้อมูลให้ได้ และผู้ใช้แก้คำแปลเองได้เสมอ

**flutter_tts ทำอะไร?** เรียกระบบ Text-to-Speech ของเครื่องให้อ่านคำ/ประโยคภาษาอังกฤษ ช่วยฝึกการออกเสียง
ความเร็วเสียงตั้งได้ในหน้า Profile และเก็บด้วย SharedPreferences ปิดแอปแล้วค่ายังอยู่

**StreamBuilder ต่างจาก FutureBuilder อย่างไร?** Future ได้ผลครั้งเดียว ส่วน Stream ส่งค่ามาเรื่อย ๆ
ทุกครั้งที่ข้อมูลเปลี่ยน ใช้ Stream เพื่อให้รายการคำอัปเดตทันที

**หน้าสุ่มทบทวนสุ่มยังไง?** ใช้ `Random().nextInt(จำนวนคำ)` จาก `dart:math` สุ่มเลขตำแหน่งในรายการคำ
กรองเฉพาะคำที่ยังไม่จำได้ และกันไม่ให้สุ่มได้คำเดิมซ้ำติดกัน กด "จำได้แล้ว" บนการ์ดจะบันทึกลง Firestore ทันที (UPDATE)

**ปุ่ม "สุ่มคำศัพท์ TOEIC" ในหน้าเพิ่มคำทำอะไร?** สุ่มคำจากรายการใน `data/toeic_words.dart`
โดยอ่านคำที่ผู้ใช้บันทึกไว้แล้วจาก Firestore ครั้งเดียว (`getWords().first`) เพื่อข้ามคำที่มีอยู่แล้ว
จากนั้นเรียก `_lookup()` ดึงความหมายและคำแปลไทยให้อัตโนมัติ ผู้ใช้แค่กด Save

**`mounted` คืออะไร?** หลัง `await` หน้าจออาจถูกปิดไปแล้ว ตรวจ `mounted` ก่อนเรียก `setState` หรือใช้ `context` เพื่อกัน error

## 6. ทดสอบ

```bash
flutter test
```

ทดสอบการแปลง JSON ของ Dictionary API และ Translate API (ไม่ต้องต่ออินเทอร์เน็ต)
