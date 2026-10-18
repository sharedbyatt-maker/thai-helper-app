import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_helper/exchange/phone_notifications.dart';

void main() {
  testWidgets('Phone notifications require an explicit opt-in, support a self-test and can be stopped', (t) async {
    final calls = <String>[];
    var active = false;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: PhoneNotifications(action: (action) async {
      calls.add(action);
      if (action == 'enable') active = true;
      if (action == 'disable') active = false;
      return {'supported': true, 'active': active};
    }))));
    await t.pumpAndSettle();
    expect(calls, ['status']);
    await t.tap(find.byKey(const ValueKey('phone_push_toggle')));
    await t.pumpAndSettle();
    expect(find.text('✓ ဖုန်း noti ဖွင့်ထားတယ်'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('phone_push_test')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('phone_push_toggle')));
    await t.pumpAndSettle();
    expect(calls, ['status', 'enable', 'test', 'disable']);
    expect(find.byKey(const ValueKey('phone_push_test')), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('The iPhone Home Screen guide and supported phone controls fit large Myanmar text at 320px', (t) async {
    for (final font in [('Noto Sans Myanmar','assets/fonts/NotoSansMyanmar.ttf'),('MaterialIcons','fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    t.view.physicalSize = const Size(320, 1100);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.4;
    for (final supported in [false, true]) {
      await t.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'Noto Sans Myanmar'),home: Scaffold(body: SingleChildScrollView(child: PhoneNotifications(key: ValueKey(supported), action: (_) async => {
        'supported': supported,
        'active': supported,
        'needs_home_screen': !supported,
        'reason': 'Safari → Share → Add to Home Screen နဲ့ ထည့်ပါ။ ပြီးရင် Home Screen က icon ကိုဖွင့်ပါ။',
      })))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(ValueKey(supported ? 'phone_push_toggle' : 'phone_push_guide')), findsOneWidget);
      if (!supported) expect(find.byKey(const ValueKey('phone_push_toggle')), findsNothing);
    }
    await t.pumpWidget(const SizedBox());
    t.view.resetPhysicalSize();t.view.resetDevicePixelRatio();t.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
