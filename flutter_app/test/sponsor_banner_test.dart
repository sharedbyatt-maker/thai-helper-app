import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thai_helper/exchange/sponsor_banner.dart';

Map<String,dynamic> conf({bool enabled=false,bool web=false,
    bool home=false,String image='https://example.com/banner.png',
    String destination='https://example.com/sponsor'})=> {
  'enabled':enabled,
  'platforms':{'web':web,'android':false,'ios':false},
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
  await tester.pumpWidget(MaterialApp(locale:const Locale('my'),home:Scaffold(body:SponsorBanner(
    placement:'home',apiBase:'https://rates.example',client:client,
  ))));
  await tester.pumpAndSettle();
}
void main(){
  testWidgets('Ads default OFF: no sponsor banner, no layout placeholder', (tester)async{
    await mount(tester,conf());
    expect(find.text('Example Sponsor'),findsNothing);
    expect(find.byKey(const ValueKey('sponsor_home')),findsNothing);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Explicitly enabled sponsor is clearly labeled', (tester)async{
    await mount(tester,conf(enabled:true,web:true,home:true));
    expect(find.text('Example Sponsor'),findsOneWidget);
    expect(find.text('ကြော်ငြာ / Sponsored'),findsOneWidget);
    expect(find.byKey(const ValueKey('sponsor_link_home')),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Unsafe sponsor URLs never render', (tester)async{
    await mount(tester,conf(enabled:true,web:true,home:true,destination:'javascript:alert(1)'));
    expect(find.text('Example Sponsor'),findsNothing);
    expect(tester.takeException(),isNull);
  });
}
