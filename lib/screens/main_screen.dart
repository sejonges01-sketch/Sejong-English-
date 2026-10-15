import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/audio_service.dart';
import 'english_quiz_screen.dart';
import 'listening_screen.dart';
import 'login_screen.dart';
import 'score_screen.dart';
import 'word_study_screen.dart';
import 'writing_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AudioService _audio = AudioService.instance;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  /// 로그인 직후에는 배경음악을 틀지 않습니다. (음악 버튼을 눌러야 재생)
  Future<void> _initAudio() async {
    _audio.isMusicOn = false;
    await _audio.initBackgroundMusic();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _audio.stopBackgroundMusic();
    super.dispose();
  }

  Future<void> _toggleMusic() async {
    await _audio.toggleBackgroundMusic();
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃', textAlign: TextAlign.center),
        content: const Text('로그인 화면으로 나갑니다', textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _audio.stopBackgroundMusic();
    if (!mounted) return;
    context.read<AuthProvider>().logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _onWillPop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('종료', textAlign: TextAlign.center),
        content: const Text('종료하시겠습니까?', textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _audio.stopBackgroundMusic();
      SystemNavigator.pop();
    }
  }

  void _go(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _menuButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.85),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AuthProvider>().student;
    final title = s == null
        ? '영어 단어 공부'
        : '${s.grade}학년 ${s.classNum}반 ${s.number}번 ${s.name}  < Level ${s.currentLevel} >';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: const TextStyle(fontSize: 16)),
          ),
          actions: [
            IconButton(
              tooltip: _audio.isMusicOn ? '음악 끄기' : '음악 켜기',
              icon: Icon(_audio.isMusicOn ? Icons.music_note : Icons.music_off),
              onPressed: _toggleMusic,
            ),
            IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE0F2F1), Color(0xFFFFF8E1)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 32).clamp(0.0, double.infinity)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppTitle(color: kPrimary),
                        const SizedBox(height: 24),
                        _menuButton('단어 익히기', Icons.menu_book,
                            const Color(0xFF42A5F5), () => _go(const WordStudyScreen())),
                        const SizedBox(height: 12),
                        _menuButton('따라 쓰기', Icons.edit,
                            const Color(0xFF66BB6A), () => _go(const WritingScreen())),
                        const SizedBox(height: 12),
                        _menuButton('듣고 쓰기', Icons.headphones,
                            const Color(0xFFFF8A65), () => _go(const ListeningScreen())),
                        const SizedBox(height: 12),
                        _menuButton('영어 퀴즈', Icons.quiz,
                            const Color(0xFFAB47BC), () => _go(const EnglishQuizScreen())),
                        const SizedBox(height: 12),
                        _menuButton('내 점수 보기', Icons.emoji_events,
                            const Color(0xFF26A69A), () => _go(const ScoreScreen())),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
