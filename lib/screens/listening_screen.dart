import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_data.dart';
import '../providers/auth_provider.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';

/// 듣고 쓰기: 발음을 듣고 영어 단어를 써 보는 연습 (점수 저장 없음)
class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  static const Color _orange = Color(0xFFE64A19);

  final AudioService _audio = AudioService.instance;
  final TtsService _tts = TtsService.instance;
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random();

  List<Word> _words = [];
  int _index = 0;
  int _correct = 0;
  bool? _lastCorrect;
  bool _showMeaning = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _load() {
    final level = context.read<AuthProvider>().student?.currentLevel ?? 1;
    final words = List<Word>.from(WordData.getWords(level))..shuffle(_random);
    setState(() {
      _words = words;
      _index = 0;
      _correct = 0;
      _lastCorrect = null;
      _showMeaning = false;
      _loaded = true;
    });
    _controller.clear();
    if (words.isNotEmpty) _tts.speak(words.first.en);
  }

  void _checkAnswer() {
    if (_lastCorrect != null) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    final ok = input.toLowerCase() == _words[_index].en.toLowerCase();
    setState(() {
      _lastCorrect = ok;
      _showMeaning = true;
      if (ok) _correct++;
    });
    ok ? _audio.playCorrectSound() : _audio.playWrongSound();
  }

  void _move(int delta) {
    final next = _index + delta;
    if (next < 0) return;
    if (next >= _words.length) {
      _showResultDialog();
      return;
    }
    setState(() {
      _index = next;
      _lastCorrect = null;
      _showMeaning = false;
    });
    _controller.clear();
    _tts.speak(_words[next].en);
  }

  void _showResultDialog() {
    final total = _words.length;
    final rate = total == 0 ? 0.0 : _correct / total * 100;
    final passed = total > 0 && _correct / total >= 0.7;
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
            Text(passed ? '잘했어요!' : '조금 더 연습해 봐요.',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: passed ? Colors.green : Colors.red)),
            const SizedBox(height: 8),
            Text('정답: $_correct / $total',
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
              _load();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _orange, foregroundColor: Colors.white),
            child: const Text('처음부터 다시'),
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

  @override
  Widget build(BuildContext context) {
    final level = context.watch<AuthProvider>().student?.currentLevel ?? 1;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        title: Text(_words.isEmpty
            ? '듣고 쓰기 (Level $level)'
            : '듣고 쓰기 (Level $level) - ${_index + 1}/${_words.length}'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? const Center(child: Text('단어 데이터가 없습니다.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildBody(),
                  ),
                ),
    );
  }

  Widget _buildBody() {
    final w = _words[_index];
    final isLast = _index >= _words.length - 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (_index + 1) / _words.length,
            minHeight: 8,
            backgroundColor: Colors.orange.shade100,
            valueColor: const AlwaysStoppedAnimation<Color>(_orange),
          ),
          const SizedBox(height: 16),
          const Text('발음을 듣고 영어 단어를 쓰세요',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 17)),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: ElevatedButton(
                onPressed: () => _tts.speak(w.en),
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  elevation: 6,
                ),
                child: const Icon(Icons.volume_up, size: 56),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: _showMeaning
                ? Text(w.ko,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, color: _orange))
                : TextButton.icon(
                    onPressed: () => setState(() => _showMeaning = true),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('뜻 보기 (힌트)'),
                  ),
          ),
          const SizedBox(height: 12),
          if (_lastCorrect != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _lastCorrect! ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _lastCorrect! ? '정답입니다!' : '오답! 정답: ${w.en}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _lastCorrect! ? Colors.green : Colors.red,
                ),
              ),
            ),
          TextField(
            controller: _controller,
            enabled: _lastCorrect == null,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, letterSpacing: 2),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _checkAnswer(),
            decoration: InputDecoration(
              hintText: 'English',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _lastCorrect == null ? _checkAnswer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _index > 0 ? () => _move(-1) : null,
                  child: const Text('이전'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _move(1),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _orange, foregroundColor: Colors.white),
                  child: Text(isLast ? '결과 보기' : '다음'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
