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
    return await _findThaiVoice() != null;
  }

  /// Explicitly select a Thai voice. Some platforms/browsers ignore
  /// setLanguage('th-TH') and fall back to a wrong-language voice,
  /// which mangles Thai pronunciation. Returns the voice map or null.
  Future<Map<String, String>?> _findThaiVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        for (final v in voices) {
          if (v is Map) {
            final locale =
                (v['locale'] ?? '').toString().toLowerCase();
            final name =
                (v['name'] ?? '').toString().toLowerCase();
            if (locale.startsWith('th') ||
                name.contains('thai') ||
                name.contains('th-th')) {
              return {
                'name': v['name'].toString(),
                'locale': v['locale'].toString(),
              };
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> speak(String text) async {
    if (!_ready) await init();
    await _tts.stop();
    final voice = await _findThaiVoice();
    if (voice != null) {
      try {
        await _tts.setVoice(voice);
      } catch (_) {}
    }
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
