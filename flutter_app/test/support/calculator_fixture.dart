import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Published rates now have a compact summary; edit controls open explicitly.
Future<void> openRateEditor(WidgetTester tester) async {
  if (find.byKey(const ValueKey('rate_0')).evaluate().isNotEmpty) return;
  final edit = find.byKey(const ValueKey('edit_rate_0'));
  if (edit.evaluate().isEmpty) return;
  await tester.ensureVisible(edit);
  await tester.pumpAndSettle();
  await tester.tap(edit);
  await tester.pumpAndSettle();
}
