import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 영어 발음 듣기 (휴대폰에 내장된 음성 엔진 사용)
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.4);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (e) {
      debugPrint('TTS 초기화 실패: $e');
    }
  }

  Future<void> speak(String text) async {
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS 재생 실패: $e');
    }
  }
}
