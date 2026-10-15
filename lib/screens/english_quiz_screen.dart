import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_data.dart';
import '../providers/auth_provider.dart';
import '../services/audio_service.dart';
import '../services/firebase_service.dart';
import '../services/tts_service.dart';
import 'king_screen.dart';

class _QuizItem {
  final String question;
  final String sub;
  final List<String> options;
  final int answerIndex;
  final String speak; // 발음할 영어 단어

  _QuizItem(this.question, this.sub, this.options, this.answerIndex, this.speak);
}

/// 영어 퀴즈: 뜻 고르기 / 단어 고르기 / 듣고 고르기 단계별 객관식 퀴즈 + 영단어왕
class EnglishQuizScreen extends StatefulWidget {
  const EnglishQuizScreen({super.key});

  @override
  State<EnglishQuizScreen> createState() => _EnglishQuizScreenState();
}

class _EnglishQuizScreenState extends State<EnglishQuizScreen> {
  static const List<String> _typeNames = ['뜻고르기', '단어고르기', '듣고고르기'];
  static const List<Color> _typeColors = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFF8E24AA),
  ];
  static const List<String> _typeTitles = ['뜻 고르기', '단어 고르기', '듣고 고르기'];
  static const Color _purple = Color(0xFF6A1B9A);

  final AudioService _audio = AudioService.instance;
  final TtsService _tts = TtsService.instance;
  final Random _random = Random();

  int? _type; // 0: 뜻고르기, 1: 단어고르기, 2: 듣고고르기
  int? _stage;
  List<_QuizItem> _items = [];
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _saving = false;

  int get _level => context.read<AuthProvider>().student?.currentLevel ?? 1;

  // ───────────────────────── 문제 만들기 ─────────────────────────

  int _getStageCount() => WordData.getTotalStages(_level);

  List<String> _withDistractors(String answer, List<String> pool) {
    final others = pool.where((p) => p != answer).toSet().toList()..shuffle(_random);
    return [answer, ...others.take(3)]..shuffle(_random);
  }

  void _startQuiz(int stage) {
    final level = _level;
    final all = WordData.getWords(level);
    final words = WordData.getStageQuestions(level, stage, _random);
    final koPool = all.map((w) => w.ko).toList();
    final enPool = all.map((w) => w.en).toList();
    final items = words.map((w) {
      switch (_type) {
        case 0: // 영어 → 뜻
          final opts = _withDistractors(w.ko, koPool);
          return _QuizItem(w.en, '', opts, opts.indexOf(w.ko), w.en);
        case 1: // 뜻 → 영어
          final opts = _withDistractors(w.en, enPool);
          return _QuizItem(w.ko, '', opts, opts.indexOf(w.en), w.en);
        default: // 소리 → 영어
          final opts = _withDistractors(w.en, enPool);
          return _QuizItem('', '', opts, opts.indexOf(w.en), w.en);
      }
    }).toList();
    setState(() {
      _stage = stage;
      _items = items;
      _index = 0;
      _score = 0;
      _selected = null;
    });
    if (_type != 1 && items.isNotEmpty) _tts.speak(items.first.speak);
  }

  // ───────────────────────── 진행 ─────────────────────────

  void _selectAnswer(int i) {
    if (_selected != null) return;
    final ok = i == _items[_index].answerIndex;
    setState(() {
      _selected = i;
      if (ok) _score++;
    });
    ok ? _audio.playCorrectSound() : _audio.playWrongSound();
    if (_type == 1) _tts.speak(_items[_index].speak);
  }

  void _nextQuestion() {
    if (_index < _items.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
      if (_type != 1) _tts.speak(_items[_index].speak);
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    final passed = _items.isNotEmpty && _score / _items.length >= 0.7;
    if (passed) await _saveScore();
    if (!mounted) return;
    final rate = _items.isEmpty ? 0.0 : _score / _items.length * 100;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                size: 64, color: passed ? Colors.amber : Colors.orange),
            const SizedBox(height: 12),
            Text(passed ? '통과입니다.' : '재도전하세요.',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: passed ? Colors.green : Colors.red)),
            const SizedBox(height: 8),
            Text('정답: $_score / ${_items.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('정답률: ${rate.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startQuiz(_stage ?? 1);
            },
            child: const Text('다시 도전'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _stage = null;
                _items = [];
              });
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _purple, foregroundColor: Colors.white),
            child: const Text('단계 선택'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveScore() async {
    final auth = context.read<AuthProvider>();
    final student = auth.student;
    final type = _type;
    final stage = _stage;
    if (student == null || type == null || stage == null) return;
    setState(() => _saving = true);
    try {
      await auth.firebaseService
          .updateScore(student, _typeNames[type], stage, _score);
      if (allCategoriesComplete(student) && student.status != '통과') {
        await auth.firebaseService.updateStatus(student);
      }
      auth.updateStudent(student);
    } catch (e) {
      debugPrint('점수 저장 실패: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  void _goBack() {
    if (_stage != null) {
      setState(() {
        _stage = null;
        _items = [];
      });
    } else if (_type != null) {
      setState(() => _type = null);
    } else {
      Navigator.pop(context);
    }
  }

  // ───────────────────────── 화면 ─────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final inQuiz = _type != null && _stage != null;
    final title = inQuiz ? '${_typeTitles[_type!]} $_stage단계' : '영어 퀴즈';

    Widget body;
    if (_type == null) {
      body = _buildTypeSelector();
    } else if (_stage == null) {
      body = _buildStageSelector();
    } else {
      body = _buildQuizBody();
    }

    return PopScope(
      canPop: _type == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
          title: Text(title),
          actions: [
            if (inQuiz)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text('점수: $_score',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final level = _level;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3E5F5), Colors.white],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Level $level 영어 퀴즈',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: _purple)),
          const SizedBox(height: 8),
          const Text('퀴즈 유형을 선택하세요',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          _typeBtn(0, '뜻 고르기', '영어 단어를 보고 알맞은 뜻 고르기', Icons.translate),
          _typeBtn(1, '단어 고르기', '뜻을 보고 알맞은 영어 단어 고르기', Icons.spellcheck),
          _typeBtn(2, '듣고 고르기', '발음을 듣고 알맞은 영어 단어 고르기', Icons.headphones),
          const SizedBox(height: 12),
          _kingBtn(level),
        ],
      ),
    );
  }

  Widget _typeBtn(int type, String title, String desc, IconData icon) {
    final color = _typeColors[type];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _type = type),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(desc,
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kingBtn(int level) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      color: const Color(0xFFFFB300),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const KingScreen())),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('영단어왕',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Level별 종합 평가 (Level $level)',
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageSelector() {
    final type = _type!;
    final level = _level;
    final count = _getStageCount();
    const per = WordData.perStage;
    final student = context.read<AuthProvider>().student;
    final color = _typeColors[type];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3E5F5), Colors.white],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text('${_typeTitles[type]} - 단계 선택',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 6),
          Text('Level $level · 단계당 $per문제',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: count,
              itemBuilder: (context, i) {
                final stage = i + 1;
                final done = student?.currentLevelData
                        .isStagePassed(_typeNames[type], stage) ??
                    false;
                return ElevatedButton(
                  onPressed: () => _startQuiz(stage),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: done ? color : Colors.white,
                    foregroundColor: done ? Colors.white : color,
                    side: BorderSide(color: color, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$stage',
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      const Text('단계', style: TextStyle(fontSize: 14)),
                      if (done) const Icon(Icons.check_circle, size: 18),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizBody() {
    if (_items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final type = _type!;
    final item = _items[_index];
    final color = _typeColors[type];
    const prompts = ['이 단어의 뜻은?', '이 뜻의 영어 단어는?', '발음을 듣고 알맞은 단어를 고르세요'];
    final isLast = _index >= _items.length - 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_index + 1) / _items.length,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Text('${_index + 1} / ${_items.length}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Text(prompts[type],
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              children: [
                if (item.question.isNotEmpty)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(item.question,
                        style: TextStyle(
                            fontSize: type == 0 ? 52 : 34,
                            fontWeight: FontWeight.bold)),
                  ),
                if (type != 1)
                  IconButton(
                    iconSize: type == 2 ? 72 : 32,
                    color: color,
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => _tts.speak(item.speak),
                  ),
                if (item.sub.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.sub,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(item.options.length, (i) => _optionButton(item, i)),
          const SizedBox(height: 12),
          if (_selected != null)
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isLast ? '결과 보기' : '다음',
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _optionButton(_QuizItem item, int i) {
    Color border = Colors.grey.shade400;
    Color? bg;
    String? mark;
    if (_selected != null) {
      if (i == item.answerIndex) {
        border = Colors.green;
        bg = Colors.green.shade50;
        mark = 'O';
      } else if (i == _selected) {
        border = Colors.red;
        bg = Colors.red.shade50;
        mark = 'X';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: () => _selectAnswer(i),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          side: BorderSide(color: border, width: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(item.options[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22)),
            ),
            if (mark != null)
              Text(mark,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: mark == 'O' ? Colors.green : Colors.red)),
          ],
        ),
      ),
    );
  }
}
