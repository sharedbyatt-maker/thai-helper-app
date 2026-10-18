import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/rates_repository.dart';
import 'support/app_update_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/budget_page.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/storage.dart';

final today=DateTime.utc(2026,10,18);
ExchangeQuote quote(int rate)=>ExchangeQuote(id:'daily-thb_mmk',label:'ဘတ်ပေး → ကျပ်ယူ',direction:ExchangeDirection.thbMmk,rateMicros:rate,sourceName:'Reference',observedAt:DateTime.utc(2026,10,17,5,31),validUntil:DateTime.utc(2026,10,18,5,31),sourceChecked:true);
void main(){
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 Future<void> reveal(WidgetTester tester,Finder finder)async{if(finder.evaluate().isEmpty){tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);await tester.pumpAndSettle();if(finder.evaluate().isEmpty){await tester.scrollUntilVisible(finder,180,scrollable:find.byType(Scrollable).first);}}await tester.ensureVisible(finder);await tester.pumpAndSettle();}
 Future<void> enter(WidgetTester tester,String key,String text)async{final f=find.byKey(ValueKey(key));await reveal(tester,f);await tester.enterText(f,text);await tester.pump();}
 Future<void> saveEntry(WidgetTester tester)async{final f=find.byKey(const ValueKey('budget_save_entry'));await reveal(tester,f);await tester.tap(f);await tester.pumpAndSettle();}
 Future<void> start(WidgetTester tester,BudgetStore store,{ExchangeQuote? rate})async{await tester.pumpWidget(MaterialApp(theme:ThemeData(useMaterial3:true,fontFamily:'Noto Sans Myanmar'),home:BudgetPage(store:store,quote:rate,today:today)));await tester.pumpAndSettle();}
 testWidgets('Income and expenses persist, can be edited/deleted, and never modify private exchange records',(tester)async{
  final store=BudgetStore(clock:()=>today),prefs=await SharedPreferences.getInstance();await prefs.setString(RecordStore.key,'Existing exchange records');
  await start(tester,store,rate:quote(133689840));expect(find.byKey(const ValueKey('budget_balance')),findsOneWidget);
  await reveal(tester,find.byKey(const ValueKey('budget_add_income')));await tester.tap(find.byKey(const ValueKey('budget_add_income')));await tester.pumpAndSettle();
  await enter(tester,'budget_amount','15000');await saveEntry(tester);expect((await store.load()).entries.single.amount,1500000);
  await tester.tap(find.byKey(const ValueKey('budget_add_expense')));await tester.pumpAndSettle();await enter(tester,'budget_amount','50');await enter(tester,'budget_note','နေ့လယ်စာ');await saveEntry(tester);
  var data=await store.load();final expense=data.entries.firstWhere((e)=>e.kind==BudgetKind.expense);expect(BudgetSummary(data,today).balance,1495000);
  final menu=find.byKey(ValueKey('budget_menu_${expense.id}'));await reveal(tester,menu);await tester.tap(menu);await tester.pumpAndSettle();await tester.tap(find.text('ပြင်မယ်').last);await tester.pumpAndSettle();await enter(tester,'budget_amount','60');await saveEntry(tester);
  expect((await store.load()).entries.firstWhere((e)=>e.id==expense.id).amount,6000);
  await reveal(tester,menu);await tester.tap(menu);await tester.pumpAndSettle();await tester.tap(find.text('ဖျက်မယ်').last);await tester.pumpAndSettle();
  expect((await store.load()).entries.length,2);await tester.tap(find.widgetWithText(FilledButton,'ဖျက်မယ်'));await tester.pumpAndSettle();
  data=await store.load();expect(data.entries.length,1);expect(BudgetSummary(data,today).balance,1500000);expect(prefs.getString(RecordStore.key),'Existing exchange records');expect(tester.takeException(),isNull);
 });
 testWidgets('Plans and actual remittances reduce reserves once and retain their original receipt despite a changed quote',(tester)async{
  final store=BudgetStore(clock:()=>today);await start(tester,store,rate:quote(133689840));
  await reveal(tester,find.byKey(const ValueKey('budget_plan')));await tester.tap(find.byKey(const ValueKey('budget_plan')));await tester.pumpAndSettle();
  for(final field in [('budget_opening','15000'),('budget_fixed','3000'),('budget_home','4000'),('budget_savings','1000')]){await enter(tester,field.$1,field.$2);}
  await reveal(tester,find.byKey(const ValueKey('budget_save_plan')));await tester.tap(find.byKey(const ValueKey('budget_save_plan')));await tester.pumpAndSettle();
  expect(BudgetSummary(await store.load(),today).available,700000);expect(find.byKey(const ValueKey('budget_remittance_estimate')),findsOneWidget);
  await reveal(tester,find.byKey(const ValueKey('budget_add_remittance')));await tester.tap(find.byKey(const ValueKey('budget_add_remittance')));await tester.pumpAndSettle();await enter(tester,'budget_amount','1000');await enter(tester,'budget_received_mmk','130000');await saveEntry(tester);
  var data=await store.load();expect(BudgetSummary(data,today).homeLeft,300000);expect(BudgetSummary(data,today).available,700000);expect(data.entries.single.receivedMmk,13000000);expect(data.entries.single.referenceRate,133689840);
  await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();await start(tester,store,rate:quote(150000000));
  data=await store.load();expect(data.entries.single.receivedMmk,13000000);expect(data.entries.single.referenceRate,133689840);expect(tester.takeException(),isNull);
 });
 testWidgets('Restoring a backup previews replacement and requires confirmation; invalid files never write',(tester)async{
  final store=BudgetStore(clock:()=>today);final existing=await store.save(const BudgetData(opening:50000),expectedRevision:0);
  final backup=store.backup(const BudgetData(opening:100000,entries:[BudgetEntry(id:'restored',day:'2026-10-17',kind:BudgetKind.expense,amount:5000,category:'food')]));
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Text('Home'))));await tester.pumpAndSettle();
  Navigator.of(tester.element(find.text('Home'))).push<void>(MaterialPageRoute(builder:(_)=>BudgetRestorePage(store:store,currentCount:0,onRestore:(value)async{await store.save(value,expectedRevision:existing.revision);})));await tester.pumpAndSettle();
  await enter(tester,'budget_backup_text',jsonEncode({'schema_version':999}));await tester.tap(find.byKey(const ValueKey('budget_preview_restore')));await tester.pumpAndSettle();expect(find.byKey(const ValueKey('budget_restore')),findsNothing);expect((await store.load()).opening,50000);
  await enter(tester,'budget_backup_text',backup);await tester.tap(find.byKey(const ValueKey('budget_preview_restore')));await tester.pumpAndSettle();
  final restore=find.byKey(const ValueKey('budget_restore'));await reveal(tester,restore);expect(tester.widget<FilledButton>(restore).onPressed,isNull);expect((await store.load()).opening,50000);
  await reveal(tester,find.byKey(const ValueKey('budget_confirm_restore')));await tester.tap(find.byKey(const ValueKey('budget_confirm_restore')));await tester.pumpAndSettle();await reveal(tester,restore);await tester.tap(restore);await tester.pumpAndSettle();expect((await store.load()).opening,100000);expect((await store.load()).entries.single.id,'restored');expect(tester.takeException(),isNull);
 });
 testWidgets('Daily and exchange-history shortcuts open the same local wallet while preserving three main tabs',(tester)async{
  await BudgetStore().save(const BudgetData(opening:123400),expectedRevision:0);
  final repo=RatesRepository(client:MockClient((r)async=>http.Response(jsonEncode(r.url.path.endsWith('/history')?{'schema_version':1,'timezone':'Asia/Bangkok','points':[]}:{'schema_version':2,'revision':1,'published_at':DateTime.now().toIso8601String(),'notice':'','quotes':[]}),200)));
  await tester.pumpWidget(CurrencyApp(repository:repo,updates:noNativeUpdates()));await tester.pumpAndSettle();
  expect(find.byType(NavigationDestination),findsNWidgets(3));
  await reveal(tester,find.byKey(const ValueKey('open_budget')));await tester.tap(find.byKey(const ValueKey('open_budget')));await tester.pumpAndSettle();
  expect(tester.widget<Text>(find.byKey(const ValueKey('budget_balance'))).data,'1,234 ဘတ်');
  await tester.pageBack();await tester.pumpAndSettle();await tester.tap(find.text('မှတ်တမ်း'));await tester.pumpAndSettle();
  await reveal(tester,find.byKey(const ValueKey('open_budget')));await tester.tap(find.byKey(const ValueKey('open_budget')));await tester.pumpAndSettle();
  expect(tester.widget<Text>(find.byKey(const ValueKey('budget_balance'))).data,'1,234 ဘတ်');expect(tester.takeException(),isNull);
 });
 testWidgets('Budget page, monthly category bars and entry editor fit 320px with large real Myanmar text',(tester)async{
  tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  for(final font in [('Noto Sans Myanmar','assets/fonts/NotoSansMyanmar.ttf'),('MaterialIcons','fonts/MaterialIcons-Regular.otf')]){await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();}
  final store=BudgetStore(clock:()=>today);await store.save(const BudgetData(opening:1500000,plans:[BudgetPlan(id:'p',start:'2026-10-01',end:'2026-11-01',fixed:300000,home:400000,savings:100000)],entries:[BudgetEntry(id:'food',day:'2026-10-17',kind:BudgetKind.expense,amount:5000,category:'food',note:'နေ့လယ်စာ')]),expectedRevision:0);
  await tester.pumpWidget(MaterialApp(theme:ThemeData(useMaterial3:true,fontFamily:'Noto Sans Myanmar'),builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(1.4)),child:child!),home:BudgetPage(store:store,quote:quote(133689840),today:today)));await tester.pumpAndSettle();
  await reveal(tester,find.byKey(const ValueKey('budget_menu_food')));expect(tester.takeException(),isNull);
  await tester.tap(find.byKey(const ValueKey('budget_add_expense')));await tester.pumpAndSettle();await enter(tester,'budget_amount','၀');await saveEntry(tester);expect(find.textContaining('ငွေပမာဏကို ပြန်စစ်ပေးပါ'),findsOneWidget);expect((await store.load()).entries.length,1);expect(tester.takeException(),isNull);
 });
}
