import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

// จุดเริ่มต้นของแอป
void main() async {
  // ต้องเรียกก่อนใช้ plugin ใด ๆ ก่อน runApp
  WidgetsFlutterBinding.ensureInitialized();

  // เชื่อมต่อ Firebase (ค่าตั้งค่ามาจากไฟล์ firebase_options.dart)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const VocabBookApp());
}

class VocabBookApp extends StatelessWidget {
  const VocabBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocab Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// AuthGate = "ประตู" ที่คอยดูว่าผู้ใช้ล็อกอินอยู่หรือไม่
// - ล็อกอินแล้ว  -> ไปหน้า HomeScreen
// - ยังไม่ล็อกอิน -> ไปหน้า LoginScreen
// authStateChanges() จะส่งค่าใหม่มาทุกครั้งที่ login / logout จึงสลับหน้าให้อัตโนมัติ
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
