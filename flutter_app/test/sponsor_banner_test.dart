import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thai_helper/exchange/sponsor_banner.dart';

Map<String,dynamic> conf({bool enabled=false,bool web=false,
    bool home=false,String image='https://example.com/banner.png',
    String destination='https://example.com/sponsor'})=> {
  'enabled':enabled,
  'platforms':{'web':web,'android':web,'ios':false},
  'placements':{'home':home,'history':false,'calculator':false,'budget':false},
  'sponsors':[{
    'id':'s1','name':'Example Sponsor','label':'An advertised service',
    'image_url':image,'destination_url':destination,
    'language':'both','placements':['home'],
  }],
};
Future<void> mount(WidgetTester tester,Map<String,dynamic> config)async{
  final client=MockClient((request)async{
    expect(request.url.path,'/api/v2/ads');
    return http.Response(jsonEncode(config),200,
       headers:{'content-type':'application/json'});
  });
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SponsorBanner(
    placement:'home',apiBase:'https://rates.example',client:client,
  ))));
  // Flush the mocked HTTP completion independently of image loading.
  await tester.pump();
  await tester.pumpAndSettle();
}
void main(){
  testWidgets('Ads default OFF: no sponsor banner, no layout placeholder', (tester)async{
    await mount(tester,conf());
    expect(find.text('Example Sponsor'),findsNothing);
    expect(find.byKey(const ValueKey('sponsor_home')),findsNothing);
    expect(tester.takeException(),isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('Explicitly enabled sponsor is clearly labeled', (tester)async{
    await mount(tester,conf(enabled:true,web:true,home:true));
    expect(find.text('Example Sponsor'),findsOneWidget);
    expect(find.text('Sponsored'),findsOneWidget);
    expect(find.byKey(const ValueKey('sponsor_link_home')),findsOneWidget);
    expect(tester.takeException(),isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('Unsafe sponsor URLs never render', (tester)async{
    await mount(tester,conf(enabled:true,web:true,home:true,destination:'javascript:alert(1)'));
    expect(find.text('Example Sponsor'),findsNothing);
    expect(tester.takeException(),isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('A late sponsor response cannot replace the selected language', (tester) async {
    final requests = <Completer<http.Response>>[];
    final client = MockClient((request) {
      final response = Completer<http.Response>();
      requests.add(response);
      return response.future;
    });
    Future<void> show(Locale locale) async {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('my'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: SponsorBanner(
          placement: 'home', apiBase: 'https://rates.example', client: client,
        )),
      ));
      await tester.pumpAndSettle();
    }
    http.Response response(String language, String name) {
      final config = conf(enabled: true, web: true, home: true);
      final sponsor = (config['sponsors'] as List).single as Map;
      sponsor['language'] = language;
      sponsor['name'] = name;
      return http.Response(jsonEncode(config), 200,
          headers: {'content-type': 'application/json'});
    }

    await show(const Locale('my'));
    expect(requests, hasLength(1));
    await show(const Locale('en'));
    expect(requests, hasLength(2));
    requests[1].complete(response('en', 'English sponsor'));
    await tester.pumpAndSettle();
    expect(find.text('English sponsor'), findsOneWidget);
    requests[0].complete(response('my', 'Previous language sponsor'));
    await tester.pumpAndSettle();
    expect(find.text('English sponsor'), findsOneWidget);
    expect(find.text('Previous language sponsor'), findsNothing);
    expect(find.text('Sponsored'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
