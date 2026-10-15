import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_config.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';

const Color kPrimary = Color(0xFF00695C);
const Color kAccent = Color(0xFFFFB300);

bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (firebaseApiKey.isNotEmpty) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: firebaseApiKey,
          appId: firebaseAppId,
          messagingSenderId: firebaseSenderId,
          projectId: firebaseProjectId,
          storageBucket: firebaseStorageBucket,
        ),
      );
      firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase 초기화 실패: $e');
    }
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SejongEnglishApp());
}

class SejongEnglishApp extends StatelessWidget {
  const SejongEnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: '세종 영어 단어',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
