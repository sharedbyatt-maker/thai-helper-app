import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Phrase {
  final String id;
  final String my; // မြန်မာလို
  final String th; // ထိုင်းလို
  final String phon; // မြန်မာအသံထွက်
  final String categoryId;

  Phrase({
    required this.id,
    required this.my,
    required this.th,
    required this.phon,
    required this.categoryId,
  });

  /// Gender-aware display: ผม -> ดิฉัน for female speakers.
  /// NOTE: v1.1 should carry proper male/female variants after Thai review.
  String displayTh(bool isMale) {
    if (isMale) return th;
    return th.replaceAll('ผม', 'ดิฉัน');
  }
}

class Category {
  final String id;
  final String my;
  final List<Phrase> phrases;

  Category({required this.id, required this.my, required this.phrases});
}

Future<List<Category>> loadCategories() async {
  final raw = await rootBundle.loadString('assets/data/phrases_v1.json');
  final data = json.decode(raw) as Map<String, dynamic>;
  final cats = <Category>[];
  for (final c in data['categories'] as List) {
    final phrases = <Phrase>[];
    var i = 0;
    for (final p in (c['phrases'] as List)) {
      phrases.add(Phrase(
        id: '${c['id']}_$i',
        my: p['my'] as String,
        th: p['th'] as String,
        phon: p['phon'] as String,
        categoryId: c['id'] as String,
      ));
      i++;
    }
    cats.add(Category(
      id: c['id'] as String,
      my: c['my'] as String,
      phrases: phrases,
    ));
  }
  return cats;
}
