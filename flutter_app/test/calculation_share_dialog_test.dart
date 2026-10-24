import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_helper/exchange/calculation_share_dialog.dart';
import 'package:thai_helper/exchange/user_language.dart' show UserLanguageScope, UserLanguage;

void main() {
  for (final fail in [false, true]) {
    testWidgets('Calculation copy keeps exact receipt and exposes visible status when clipboard fails=$fail', (t) async {
      const receipt = 'You pay 10,000 THB\nYou receive 1,351,351.35 MMK\nPrivate note';
      String? copied;
      await t.pumpWidget(UserLanguageScope(language: UserLanguage.english, onChanged: (_) {}, child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showDialog<void>(context: context, builder: (_) => CalculationShareDialog(receipt: receipt, copy: (text) async { copied = text; if (fail) throw Exception('clipboard denied'); })), child: const Text('open')))))));
      await t.tap(find.text('open')); await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('calculation_share_text')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('calculation_share_copy'))); await t.pumpAndSettle();
      expect(copied, receipt);
      expect(find.text(fail ? 'Could not copy. Select the text below and copy it manually.' : 'Text copied.'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
