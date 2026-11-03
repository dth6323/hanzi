import 'dart:convert';

import 'package:flutter_tts/flutter_tts.dart';

import '../data/db_bridge.dart';
import '../data/http_post_stub.dart'
    if (dart.library.io) '../data/http_post_io.dart'
    if (dart.library.html) '../data/http_post_web.dart';

/// Offline text-to-speech using the device's Chinese voice on Android/iOS,
/// with automatic bridge fallback when previewing on Linux Desktop / Chrome.
class Speaker {
  Speaker._();
  static final Speaker instance = Speaker._();
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool available = true;
  double rate = 0.45;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      final ok = await _tts.isLanguageAvailable('zh-CN');
      available = ok == true || ok == 1;
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(rate);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      available = false;
    }
  }

  Future<void> speak(String text, {bool slow = false}) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    if (useHttpBridge) {
      try {
        await postJson(
          'http://127.0.0.1:43821/tts',
          jsonEncode({'text': cleaned, 'slow': slow}),
        );
        return;
      } catch (_) {}
    }

    await _init();
    await _tts.stop();
    await _tts.setSpeechRate(slow ? rate * 0.6 : rate);
    await _tts.speak(cleaned);
  }
}
