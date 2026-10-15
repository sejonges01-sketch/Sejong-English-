import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_data.dart';
import '../providers/auth_provider.dart';
import '../services/tts_service.dart';
import 'spelling_quiz_screen.dart';

/// 단어 익히기: 20개씩 보며 뜻과 발음을 익히는 화면
class WordStudyScreen extends StatefulWidget {
  const WordStudyScreen({super.key});

  @override
  State<WordStudyScreen> createState() => _WordStudyScreenState();
}

class _WordStudyScreenState extends State<WordStudyScreen> {
  static const int _pageSize = WordData.perStage;
  static const Color _blue = Color(0xFF1565C0);
  final TtsService _tts = TtsService.instance;
  int _page = 0;
  bool _hideMeaning = false;

  void _showDetail(Word w) {
    _tts.speak(w.en);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(w.en,
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Text(w.ko,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, color: _blue)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _tts.speak(w.en),
              icon: const Icon(Icons.volume_up),
              label: const Text('발음 듣기'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = context.watch<AuthProvider>().student?.currentLevel ?? 1;
    final all = WordData.getWords(level);
    final totalPages = all.isEmpty ? 1 : ((all.length - 1) ~/ _pageSize) + 1;
    final page = _page.clamp(0, totalPages - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize) > all.length ? all.length : start + _pageSize;
    final items = all.isEmpty ? <Word>[] : all.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text('단어 익히기 (Level $level)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SpellingQuizScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _blue,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.quiz),
              label: const Text('철자 퀴즈'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Container(
                color: const Color(0xFFE3F2FD),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed:
                          page > 0 ? () => setState(() => _page = page - 1) : null,
                    ),
                    Text('${page + 1} / $totalPages 페이지',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: page < totalPages - 1
                          ? () => setState(() => _page = page + 1)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('뜻 가리기'),
                      selected: _hideMeaning,
                      onSelected: (v) => setState(() => _hideMeaning = v),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final w = items[i];
                    return Material(
                      color: Colors.white,
                      elevation: 1,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _blue.withValues(alpha: 0.4)),
                        ),
                        onTap: () => _showDetail(w),
                        leading: CircleAvatar(
                          backgroundColor: _blue.withValues(alpha: 0.12),
                          child: Text('${start + i + 1}',
                              style: const TextStyle(fontSize: 13, color: _blue)),
                        ),
                        title: Text(w.en,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        subtitle: Text(_hideMeaning ? '•  •  •' : w.ko,
                            style: const TextStyle(fontSize: 16)),
                        trailing: IconButton(
                          icon: const Icon(Icons.volume_up, color: _blue),
                          onPressed: () => _tts.speak(w.en),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
