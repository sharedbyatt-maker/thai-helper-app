import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device TTS wrapper (Android: Google TTS, iOS: AVSpeechSynthesizer).
/// Free, offline, no API key. Thai voice pack may need one-time download
/// on Android -> see SettingsScreen for the user-facing check.
class TtsService {
  static final TtsService _i = TtsService._internal();
  factory TtsService() => _i;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    await _tts.setLanguage('th-TH');
    await _tts.setSpeechRate(0.45); // slower = clearer for learners
    await _tts.setPitch(1.0);
    _ready = true;
  }

  Future<bool> get isThaiAvailable async {
    try {
      final langs = await _tts.getLanguages;
      if (langs is List) {
        return langs.any(
            (l) => l.toString().toLowerCase().startsWith('th'));
      }
    } catch (_) {}
    return false;
  }

  Future<void> speak(String text) async {
    if (!_ready) await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}

/// SharedPreferences wrapper: gender toggle + favorites.
class Prefs {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static bool get isMale => _p?.getBool('isMale') ?? true;
  static Future<void> setIsMale(bool v) async {
    await _p?.setBool('isMale', v);
  }

  static Set<String> get favorites =>
      Set<String>.from(_p?.getStringList('favorites') ?? []);

  static Future<void> toggleFavorite(String id) async {
    final f = favorites;
    if (f.contains(id)) {
      f.remove(id);
    } else {
      f.add(id);
    }
    await _p?.setStringList('favorites', f.toList());
  }
}
