import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 배경음악·효과음 (안드로이드 MainActivity의 네이티브 재생 기능 사용)
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const MethodChannel _channel = MethodChannel('sejong_english/audio');

  bool isMusicOn = false;
  bool _initialized = false;

  Future<void> initBackgroundMusic() async {
    if (_initialized) return;
    try {
      await _channel.invokeMethod('init');
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing audio: $e');
    }
  }

  Future<void> playBackgroundMusic() async {
    try {
      await _channel.invokeMethod('playBgm');
    } catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await _channel.invokeMethod('stopBgm');
    } catch (e) {
      debugPrint('Error stopping background music: $e');
    }
  }

  Future<void> toggleBackgroundMusic() async {
    isMusicOn = !isMusicOn;
    if (isMusicOn) {
      await playBackgroundMusic();
    } else {
      await stopBackgroundMusic();
    }
  }

  Future<void> playCorrectSound() => _effect('good.mp3');
  Future<void> playWrongSound() => _effect('bad.mp3');

  Future<void> _effect(String asset) async {
    try {
      await _channel.invokeMethod('playEffect', {'asset': asset});
    } catch (e) {
      debugPrint('Error playing effect: $e');
    }
  }
}
