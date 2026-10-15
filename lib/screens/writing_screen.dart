import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_data.dart';
import '../providers/auth_provider.dart';
import '../services/tts_service.dart';

/// 따라 쓰기: 흐린 영어 단어 위에 손가락으로 따라 써 보는 연습
class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  static const Color _green = Color(0xFF2E7D32);

  int _index = 0;
  final List<List<Offset>> _strokes = [];

  final TtsService _tts = TtsService.instance;

  List<Word> get _wordList {
    final level = context.read<AuthProvider>().student?.currentLevel ?? 1;
    return WordData.getWords(level);
  }

  void _goNext() {
    if (_index < _wordList.length - 1) {
      setState(() {
        _index++;
        _strokes.clear();
      });
    }
  }

  void _goPrev() {
    if (_index > 0) {
      setState(() {
        _index--;
        _strokes.clear();
      });
    }
  }

  void _clearCanvas() => setState(() => _strokes.clear());

  Widget _actionButton(String label, IconData icon, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = context.watch<AuthProvider>().student?.currentLevel ?? 1;
    final list = WordData.getWords(level);
    if (list.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('따라 쓰기')),
        body: const Center(child: Text('단어 데이터가 없습니다.')),
      );
    }
    final index = _index.clamp(0, list.length - 1);
    final h = list[index];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text('따라 쓰기 (Level $level)'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(h.ko,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: _green),
                      onPressed: () => _tts.speak(h.en),
                    ),
                  ],
                ),
                Text('${index + 1} / ${list.length}',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _green, width: 3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: GestureDetector(
                            onPanStart: (d) => setState(
                                () => _strokes.add([d.localPosition])),
                            onPanUpdate: (d) => setState(() {
                              if (_strokes.isEmpty) _strokes.add([]);
                              _strokes.last.add(d.localPosition);
                            }),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(painter: _GuideLinePainter()),
                                Center(
                                  child: FittedBox(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        h.en,
                                        style: TextStyle(
                                          fontSize: 200,
                                          color: Colors.grey.withValues(alpha: 0.25),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                CustomPaint(
                                  painter: _DrawingPainter(_strokes),
                                  size: Size.infinite,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionButton('이전', Icons.chevron_left, index > 0 ? _goPrev : null),
                    _actionButton('지우기', Icons.delete_outline, _clearCanvas),
                    _actionButton('다음', Icons.chevron_right,
                        index < list.length - 1 ? _goNext : null),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawLine(s.first, s.first, paint);
      }
      for (var i = 0; i < s.length - 1; i++) {
        canvas.drawLine(s[i], s[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GuideLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.3)
      ..strokeWidth = 1.5;
    const dash = 8.0;
    // 영어 공책처럼 가로 4줄 (가운데 두 줄은 점선)
    final ys = [0.2, 0.4, 0.6, 0.8];
    for (var i = 0; i < ys.length; i++) {
      final y = size.height * ys[i];
      if (i == 0 || i == ys.length - 1) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      } else {
        for (double x = 0; x < size.width; x += dash * 2) {
          canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
