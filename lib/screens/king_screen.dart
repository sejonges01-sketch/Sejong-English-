import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_data.dart';
import '../providers/auth_provider.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';

class _KingItem {
  final String question;
  final String sub;
  final List<String> options;
  final int answerIndex;
  final String speak;

  _KingItem(this.question, this.sub, this.options, this.answerIndex, this.speak);
}

/// 영단어왕: Level별 종합 평가 (40문제)
/// 뜻 고르기 15, 단어 고르기 15, 듣고 고르기 10
class KingScreen extends StatefulWidget {
  const KingScreen({super.key});

  @override
  State<KingScreen> createState() => _KingScreenState();
}

class _KingScreenState extends State<KingScreen> {
  static const Color _gold = Color(0xFFFF8F00);

  final AudioService _audio = AudioService.instance;
  final TtsService _tts = TtsService.instance;
  final Random _random = Random();

  List<_KingItem> _items = [];
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _finished = false;
  bool _newRecord = false;
  int _prevBest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateQuiz());
  }

  int get _level => context.read<AuthProvider>().student?.currentLevel ?? 1;

  List<T> _pick<T>(List<T> all, int count) {
    if (all.isEmpty) return [];
    final result = <T>[];
    var bag = <T>[];
    while (result.length < count) {
      if (bag.isEmpty) bag = List<T>.from(all)..shuffle(_random);
      result.add(bag.removeLast());
    }
    return result;
  }

  List<String> _options(String answer, List<String> pool) {
    final others = pool.where((p) => p != answer).toSet().toList()..shuffle(_random);
    return [answer, ...others.take(3)]..shuffle(_random);
  }

  void _generateQuiz() {
    final words = WordData.getWords(_level);
    final koPool = words.map((w) => w.ko).toList();
    final enPool = words.map((w) => w.en).toList();
    final items = <_KingItem>[];

    for (final w in _pick(words, 15)) {
      final opts = _options(w.ko, koPool);
      items.add(_KingItem(w.en, '이 단어의 뜻은?', opts, opts.indexOf(w.ko), w.en));
    }
    for (final w in _pick(words, 15)) {
      final opts = _options(w.en, enPool);
      items.add(_KingItem(w.ko, '이 뜻의 영어 단어는?', opts, opts.indexOf(w.en), w.en));
    }
    for (final w in _pick(words, 10)) {
      final opts = _options(w.en, enPool);
      items.add(_KingItem('', '발음을 듣고 알맞은 단어를 고르세요', opts, opts.indexOf(w.en), w.en));
    }

    items.shuffle(_random);
    setState(() {
      _items = items;
      _index = 0;
      _score = 0;
      _selected = null;
      _finished = false;
      _newRecord = false;
    });
    _speakIfNeeded();
  }

  /// 한국어 뜻 문제가 아니면 발음을 들려줌
  void _speakIfNeeded() {
    if (_items.isEmpty) return;
    final item = _items[_index];
    if (item.question.isEmpty || item.question == item.speak) {
      _tts.speak(item.speak);
    }
  }

  void _selectAnswer(int i) {
    if (_selected != null) return;
    final ok = i == _items[_index].answerIndex;
    setState(() {
      _selected = i;
      if (ok) _score++;
    });
    ok ? _audio.playCorrectSound() : _audio.playWrongSound();

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      if (_index < _items.length - 1) {
        setState(() {
          _index++;
          _selected = null;
        });
        _speakIfNeeded();
      } else {
        _finishQuiz();
      }
    });
  }

  Future<void> _finishQuiz() async {
    final auth = context.read<AuthProvider>();
    final student = auth.student;
    final key = _level.toString();
    final prev = student?.kingScores[key] ?? 0;
    setState(() {
      _finished = true;
      _prevBest = prev;
      _newRecord = _score > prev;
    });
    if (student != null && _score > prev) {
      student.kingScores[key] = _score;
      try {
        await auth.firebaseService.updateKingScore(student, _level, _score);
      } catch (e) {
        debugPrint('영단어왕 점수 저장 실패: $e');
      }
      auth.updateStudent(student);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = context.watch<AuthProvider>().student?.currentLevel ?? 1;
    if (_finished) return _buildResultScreen(level);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _gold,
        foregroundColor: Colors.white,
        title: Text('영단어왕 (Level $level)'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('점수: $_score',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildQuestion(),
              ),
            ),
    );
  }

  Widget _buildQuestion() {
    final item = _items[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('문제 ${_index + 1} / ${_items.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (_index + 1) / _items.length,
            minHeight: 8,
            color: _gold,
            backgroundColor: _gold.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 6),
          Text('정답: $_score',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Text(item.sub,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold, width: 2),
            ),
            child: Column(
              children: [
                if (item.question.isNotEmpty)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(item.question,
                        style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.bold)),
                  ),
                if (item.question.isEmpty || item.question == item.speak)
                  IconButton(
                    iconSize: item.question.isEmpty ? 72 : 32,
                    color: _gold,
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => _tts.speak(item.speak),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(item.options.length, (i) {
            Color border = Colors.grey.shade400;
            Color? bg;
            if (_selected != null) {
              if (i == item.answerIndex) {
                border = Colors.green;
                bg = Colors.green.shade50;
              } else if (i == _selected) {
                border = Colors.red;
                bg = Colors.red.shade50;
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                onPressed: () => _selectAnswer(i),
                style: OutlinedButton.styleFrom(
                  backgroundColor: bg,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: border, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(item.options[i], style: const TextStyle(fontSize: 22)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultScreen(int level) {
    final total = _items.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _gold,
        foregroundColor: Colors.white,
        title: Text('영단어왕 (Level $level) 결과'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium, size: 96, color: _gold),
              const SizedBox(height: 12),
              const Text('영단어왕 퀴즈 완료!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('$_score / $total',
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.bold, color: _gold)),
              const SizedBox(height: 12),
              if (_newRecord)
                const Text('🎉 신기록 달성!',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent)),
              const SizedBox(height: 8),
              Text('이전 최고 점수: $_prevBest',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
              const SizedBox(height: 28),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _gold, foregroundColor: Colors.white),
                  child: const Text('돌아가기', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
