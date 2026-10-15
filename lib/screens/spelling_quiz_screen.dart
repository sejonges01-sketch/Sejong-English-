import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_data.dart';
import '../providers/auth_provider.dart';
import '../services/audio_service.dart';
import '../services/firebase_service.dart';
import '../services/tts_service.dart';

/// 철자 퀴즈: 뜻과 발음을 듣고 영어 단어를 직접 입력 (단계별, 70% 이상 통과)
class SpellingQuizScreen extends StatefulWidget {
  const SpellingQuizScreen({super.key});

  @override
  State<SpellingQuizScreen> createState() => _SpellingQuizScreenState();
}

class _SpellingQuizScreenState extends State<SpellingQuizScreen> {
  static const String _category = '철자쓰기';
  static const Color _blue = Color(0xFF1565C0);

  final AudioService _audio = AudioService.instance;
  final Random _random = Random();
  final TtsService _tts = TtsService.instance;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<Word> _questions = [];
  int _stage = 1;
  int _index = 0;
  int _correct = 0;
  bool? _lastCorrect;
  bool _answered = false;
  bool _ready = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStage());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _level => context.read<AuthProvider>().student?.currentLevel ?? 1;

  void _initStage() {
    final student = context.read<AuthProvider>().student;
    if (student == null) return;
    final passed = student.scores[_category] ?? 0;
    final total = WordData.getTotalStages(student.currentLevel);
    _stage = passed >= total ? 1 : passed + 1;
    _generateQuestions();
  }

  void _generateQuestions() {
    final questions = WordData.getStageQuestions(_level, _stage, _random);
    setState(() {
      _questions = questions;
      _index = 0;
      _correct = 0;
      _lastCorrect = null;
      _answered = false;
      _ready = true;
    });
    _controller.clear();
    if (questions.isNotEmpty) _tts.speak(questions.first.en);
  }

  void _checkAnswer() {
    if (_answered || _questions.isEmpty) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final q = _questions[_index];
    final ok = input.toLowerCase() == q.en.toLowerCase();
    setState(() {
      _answered = true;
      _lastCorrect = ok;
      if (ok) _correct++;
    });
    ok ? _audio.playCorrectSound() : _audio.playWrongSound();

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_index < _questions.length - 1) {
        setState(() {
          _index++;
          _answered = false;
          _lastCorrect = null;
        });
        _controller.clear();
        _focus.requestFocus();
        _tts.speak(_questions[_index].en);
      } else {
        _finishStage();
      }
    });
  }

  Future<void> _finishStage() async {
    final auth = context.read<AuthProvider>();
    final student = auth.student;
    if (student == null) return;
    final passed = _correct / _questions.length >= 0.7;

    if (passed) {
      setState(() => _saving = true);
      try {
        await auth.firebaseService
            .updateScore(student, _category, _stage, _correct);
        if (allCategoriesComplete(student) && student.status != '통과') {
          await auth.firebaseService.updateStatus(student);
          auth.updateStudent(student);
          if (!mounted) return;
          setState(() => _saving = false);
          _showCongratulationsDialog();
          return;
        }
      } catch (e) {
        debugPrint('점수 저장 실패: $e');
      }
      auth.updateStudent(student);
      if (!mounted) return;
      setState(() => _saving = false);
    }
    _showStageResultDialog(passed);
  }

  void _showStageResultDialog(bool passed) {
    final total = WordData.getTotalStages(_level);
    final rate = _correct / _questions.length * 100;
    final hasNext = passed && _stage < total;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          passed ? '단계 통과!' : '아쉽습니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: passed ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                size: 64, color: passed ? Colors.amber : Colors.orange),
            const SizedBox(height: 12),
            Text(passed ? '통과입니다.' : '재도전하세요.',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: passed ? Colors.green : Colors.red)),
            const SizedBox(height: 8),
            Text('정답: $_correct / ${_questions.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('정답률: ${rate.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!passed)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _generateQuestions();
              },
              child: const Text('다시 도전'),
            ),
          if (hasNext)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _stage++;
                _generateQuestions();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
              child: const Text('다음 단계'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('나가기'),
          ),
        ],
      ),
    );
  }

  void _showCongratulationsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('축하합니다!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            const SizedBox(height: 12),
            Text('Level $_level의 모든 영역을 통과했습니다!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('메인으로'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = context.watch<AuthProvider>().student?.currentLevel ?? 1;
    final total = WordData.getTotalStages(level);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text('철자 퀴즈 (Level $level) - $_stage/$total단계'),
      ),
      body: !_ready || _questions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildQuizView(),
              ),
            ),
    );
  }

  Widget _buildQuizView() {
    final q = _questions[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_index + 1) / _questions.length,
            minHeight: 8,
            backgroundColor: Colors.blue.shade100,
            valueColor: const AlwaysStoppedAnimation<Color>(_blue),
          ),
          const SizedBox(height: 8),
          Text('${_index + 1} / ${_questions.length}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(q.ko,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _tts.speak(q.en),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('발음 듣기'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('뜻과 발음을 듣고 영어 단어를 쓰세요',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          if (_lastCorrect != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _lastCorrect! ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_lastCorrect! ? Icons.check_circle : Icons.cancel,
                      color: _lastCorrect! ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _lastCorrect! ? '정답입니다!' : '오답! 정답: ${q.en}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _lastCorrect! ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: !_answered,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 26, letterSpacing: 2),
            onSubmitted: (_) => _checkAnswer(),
            decoration: InputDecoration(
              hintText: 'English',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _answered || _saving ? null : _checkAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3))
                  : const Text('확인', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
