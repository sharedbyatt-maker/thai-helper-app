import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Rich phrase schema adopted from the thai-for-myanmar content audit
/// (500 phrases, reviewed). Proper gender variants included.
class Phrase {
  final String id;
  final String categoryId;
  final String thai; // combined form, e.g. "สวัสดีครับ / สวัสดีค่ะ"
  final String? thaiMale;
  final String? thaiFemale;
  final String my;
  final String pronunciation; // Burmese reading aid
  final String? en;
  final List<String> keywords;
  final List<String> tags;

  Phrase({
    required this.id,
    required this.categoryId,
    required this.thai,
    this.thaiMale,
    this.thaiFemale,
    required this.my,
    required this.pronunciation,
    this.en,
    required this.keywords,
    required this.tags,
  });

  factory Phrase.fromJson(Map<String, dynamic> j) => Phrase(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String,
        thai: j['thai'] as String,
        thaiMale: j['thaiMale'] as String?,
        thaiFemale: j['thaiFemale'] as String?,
        my: j['my'] as String,
        pronunciation: (j['pronunciation'] ?? '') as String,
        en: j['en'] as String?,
        keywords: List<String>.from(j['keywords'] ?? const []),
        tags: List<String>.from(j['tags'] ?? const []),
      );

  /// Proper gender-specific Thai. Falls back to the combined form.
  String displayThai(bool isMale) {
    if (isMale) {
      final m = thaiMale;
      if (m != null && m.isNotEmpty) return m;
    } else {
      final f = thaiFemale;
      if (f != null && f.isNotEmpty) return f;
    }
    return thai;
  }

  bool matches(String q) {
    final query = q.toLowerCase();
    return my.contains(q) ||
        thai.contains(q) ||
        pronunciation.contains(q) ||
        (en != null && en!.toLowerCase().contains(query)) ||
        keywords.any((k) => k.contains(q));
  }
}

class Category {
  final String id;
  final String my;
  final String th;
  final String en;
  final String kind;
  final String icon;

  Category({
    required this.id,
    required this.my,
    required this.th,
    required this.en,
    required this.kind,
    required this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        my: j['my'] as String? ?? '',
        th: j['th'] as String? ?? '',
        en: j['en'] as String? ?? '',
        kind: j['kind'] as String? ?? 'learn',
        icon: j['icon'] as String? ?? '💬',
      );
}

class ContentBundle {
  final List<Category> categories;
  final List<Phrase> phrases;
  final Map<String, List<Phrase>> byCategory;

  ContentBundle(this.categories, this.phrases)
      : byCategory = {
          for (final c in categories)
            c.id: phrases
                .where((p) => p.categoryId == c.id)
                .toList(),
        };
}

Future<ContentBundle> loadContent() async {
  final catsRaw =
      await rootBundle.loadString('assets/data/phrase_categories.json');
  final phrasesRaw =
      await rootBundle.loadString('assets/data/phrases.json');
  final categories = (json.decode(catsRaw) as List)
      .map((c) => Category.fromJson(c as Map<String, dynamic>))
      .toList();
  final phrases = (json.decode(phrasesRaw) as List)
      .map((p) => Phrase.fromJson(p as Map<String, dynamic>))
      .toList();
  return ContentBundle(categories, phrases);
}
