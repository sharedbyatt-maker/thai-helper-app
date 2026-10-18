import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/app_updates.dart';

Map<String, dynamic> manifest({int apkBuild = 2, int playBuild = 3}) => {
  'release': {
    'schema_version': 1,
    'package_id': 'com.test.bahtzay',
    'apk': {'enabled': true, 'build': apkBuild, 'version': '1.0.10', 'notes': 'ငွေတွက်ရလဒ် ပြင်ထားတယ်။', 'url': 'https://github.com/test/bahtzay/releases/download/v1.0.10/app.apk'},
    'play': {'enabled': true, 'build': playBuild, 'version': '1.0.11', 'notes': 'Play update', 'url': 'https://play.google.com/store/apps/details?id=com.test.bahtzay'},
  },
};
const apk = InstalledApp('com.test.bahtzay', '1.0.9', 1);
const play = InstalledApp('com.test.bahtzay', '1.0.9', 1, installer: 'com.android.vending');
AppUpdateService service({bool offline = false, int build = 2}) => AppUpdateService(
  installedApp: () async => apk,
  client: MockClient((request) async {
    expect(request.url.path, '/api/v2/app-release');
    return http.Response(offline ? 'unavailable' : jsonEncode(manifest(apkBuild: build)), offline ? 503 : 200, headers: {'content-type': 'application/json; charset=utf-8'});
  }),
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Update selection uses numeric build and the actual installer channel', () {
    final direct = AvailableAppUpdate.parse(manifest(), apk)!;
    expect(direct.channel, 'apk');expect(direct.build, 2);expect(direct.url.path, endsWith('.apk'));
    final store = AvailableAppUpdate.parse(manifest(), play)!;
    expect(store.channel, 'play');expect(store.build, 3);expect(store.url.host, 'play.google.com');
    expect(AvailableAppUpdate.parse(manifest(), const InstalledApp('com.test.bahtzay', '1.0.10', 2)), isNull);
    expect(AvailableAppUpdate.parse(manifest(), const InstalledApp('com.test.bahtzay', '2.0.0', 50)), isNull);
    expect(AvailableAppUpdate.parse({'release': {'schema_version': 1, 'package_id': '', 'apk': null, 'play': null}}, apk), isNull);
  });
  test('An update never opens another package, another store or an unsafe APK link', () {
    expect(() => AvailableAppUpdate.parse(manifest(), const InstalledApp('com.other.app', '1.0.0', 1)), throwsFormatException);
    for (final url in ['javascript:alert(1)', 'http://example.test/app.apk', 'https://example.test/page', 'https://user:pass@example.test/app.apk']) {
      final data = manifest();(data['release']['apk'] as Map)['url'] = url;
      expect(() => AvailableAppUpdate.parse(data, apk), throwsFormatException);
    }
    final data = manifest();(data['release']['play'] as Map)['url'] = 'https://play.google.com/store/apps/details?id=com.other.app';
    expect(() => AvailableAppUpdate.parse(data, play), throwsFormatException);
  });
  testWidgets('The update prompt shows changes, opens the APK and stays usable at 320px with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    Uri? opened;
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.4)), child: child!), home: Scaffold(body: AppUpdateDialog(initial: AppUpdateCheck(apk, AvailableAppUpdate.parse(manifest(), apk)), openUrl: (url) async {opened = url;return true;}))));
    await tester.pumpAndSettle();
    expect(find.text('Version အသစ်ရပြီ'), findsOneWidget);
    expect(find.text('ငွေတွက်ရလဒ် ပြင်ထားတယ်။'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('app_update_download')));
    await tester.tap(find.byKey(const ValueKey('app_update_download')));
    await tester.pumpAndSettle();
    expect(opened?.path, endsWith('.apk'));expect(tester.takeException(), isNull);
  });
  testWidgets('A dismissed update is snoozed, while a newer build is announced', (tester) async {
    Widget app(int key, int build) => MaterialApp(home: AppUpdateHost(key: ValueKey(key), service: service(build: build), child: const Scaffold(body: Text('Calculator remains available'))));
    await tester.pumpWidget(app(1, 2));await tester.pumpAndSettle();
    expect(find.text('Version အသစ်ရပြီ'), findsOneWidget);
    await tester.tap(find.text('နောက်မှလုပ်မယ်'));await tester.pumpAndSettle();
    await tester.pumpWidget(app(2, 2));await tester.pumpAndSettle();
    expect(find.text('Version အသစ်ရပြီ'), findsNothing);
    expect(find.text('Calculator remains available'), findsOneWidget);
    await tester.pumpWidget(app(3, 3));await tester.pumpAndSettle();
    expect(find.text('Version အသစ်ရပြီ'), findsOneWidget);
    await tester.tap(find.text('နောက်မှလုပ်မယ်'));await tester.pumpAndSettle();
  });
  testWidgets('An offline update service never blocks the app and manual checks explain failures', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AppUpdateHost(service: service(offline: true), child: const Scaffold(body: Text('Calculator remains available')))));
    await tester.pumpAndSettle();expect(find.text('Calculator remains available'), findsOneWidget);
    expect(find.text('Version အသစ်ရပြီ'), findsNothing);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AppUpdateDialog(service: service(offline: true)))));
    await tester.pumpAndSettle();expect(find.textContaining('Update စစ်မရသေးဘူး'), findsOneWidget);expect(find.text('ပြန်စစ်မယ်'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
