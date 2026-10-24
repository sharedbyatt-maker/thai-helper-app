import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/storage.dart';

final today=DateTime.utc(2026,10,18);
const period=BudgetPlan(id:'oct',start:'2026-10-01',end:'2026-11-01',fixed:300000,home:400000,savings:100000);
BudgetEntry row(String id,BudgetKind kind,int amount,{String day='2026-10-18',bool fixed=false,int? mmk})=>BudgetEntry(id:id,day:day,kind:kind,amount:amount,category:kind==BudgetKind.income?'salary':kind==BudgetKind.remittance?'family':'home',fromFixed:fixed,receivedMmk:mmk);
void main(){
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('Separated expense categories and legacy bills round-trip without rewriting records',(){
  for(final category in ['bills','phone','utilities','shopping','personal','documents','leisure']){
   final original=BudgetEntry(id:category,day:'2026-10-18',kind:BudgetKind.expense,amount:12345,category:category,fromFixed:category=='bills');
   final restored=BudgetEntry.fromJson(jsonDecode(jsonEncode(original.toJson())) as Map<String,dynamic>,today:today);
   expect(restored.toJson(),original.toJson());
  }
  expect(budgetExpenseCategories['phone'],'ဖုန်း / အင်တာနက်');
  expect(budgetExpenseCategories['utilities'],'မီးဖိုး / ရေဖိုး');
 });
 test('Actual cash and outstanding reserves do not deduct paid bills or remittances twice',(){
  final data=BudgetData(opening:200000,plans:[period],entries:[row('salary',BudgetKind.income,1500000)]);
  expect(BudgetSummary(data,today).available,900000);
  final paid=data.copy(entries:[...data.entries,row('rent',BudgetKind.expense,300000,fixed:true),row('home',BudgetKind.remittance,200000,mmk:27000000)]);
  final summary=BudgetSummary(paid,today);
  expect(summary.balance,1200000);expect(summary.fixedLeft,0);expect(summary.homeLeft,200000);expect(summary.available,900000);expect(summary.daysLeft,14);expect(summary.daily,64285);
  final spent=BudgetSummary(paid.copy(entries:[...paid.entries,row('food',BudgetKind.expense,5000)]),today);
  expect(spent.available,895000);
  final undone=BudgetSummary(paid.copy(entries:paid.entries.where((e)=>e.id!='rent').toList()),today);
  expect(undone.fixedLeft,300000);expect(undone.available,900000);
 });
 test('Overspent categories never produce negative reserves or a positive daily allowance from missing money',(){
  final data=BudgetData(plans:[period],entries:[row('rent',BudgetKind.expense,400000,fixed:true),row('home',BudgetKind.remittance,600000)]);
  final s=BudgetSummary(data,today);expect(s.fixedLeft,0);expect(s.homeLeft,0);expect(s.balance,-1000000);expect(s.available,-1100000);expect(s.daily,0);
  expect(budgetMoney(-1),'-0.01');expect(budgetMoney(-125099),'-1,250.99');
 });
 test('Monthly reports separate actual MMK receipts and sum a transfer as a THB outflow once',(){
  final data=BudgetData(opening:999999,entries:[row('old',BudgetKind.income,10000,day:'2026-09-30'),row('salary',BudgetKind.income,1500000),row('food',BudgetKind.expense,5000),row('home',BudgetKind.remittance,100000,mmk:13000000)]);
  final report=BudgetMonth(data,DateTime.utc(2026,10));expect(report.entries.length,3);expect(report.total(BudgetKind.income),1500000);expect(report.out,105000);expect(report.categories.values.reduce((a,b)=>a+b),105000);
  expect(budgetDay(budgetToday(DateTime.utc(2026,9,30,16,59))),'2026-09-30');expect(budgetDay(budgetToday(DateTime.utc(2026,9,30,17))),'2026-10-01');
 });
 test('Expired periods keep reserves protected until a new plan takes effect; older payments do not consume a new plan',(){
  const old=BudgetPlan(id:'old',start:'2026-09-01',end:'2026-10-01',fixed:10000,savings:20000);
  const data=BudgetData(opening:100000,plans:[old]);expect(BudgetSummary(data,today).protected,30000);expect(BudgetSummary(data,today).daily,isNull);
  final late=BudgetSummary(data.copy(entries:[row('late-bill',BudgetKind.expense,10000,fixed:true)]),today);expect(late.fixedLeft,0);expect(late.protected,20000);
  final next=data.copy(plans:[old,period],entries:[row('past',BudgetKind.expense,10000,day:'2026-09-30',fixed:true)]);
  expect(BudgetSummary(next,today).fixedLeft,300000);
 });
 test('Backup round-trips the original receipts, reference quote and period settings without live repricing',(){
  const transfer=BudgetEntry(id:'receipt',day:'2026-10-17',kind:BudgetKind.remittance,amount:74800,category:'family',receivedMmk:10000000,referenceRate:133689840,referenceAt:'2026-10-17T05:31:00.000Z');
  const data=BudgetData(opening:1000000,plans:[period],entries:[transfer]);final store=BudgetStore(clock:()=>today);
  final restored=store.decode(store.backup(data));expect(restored.toJson(),data.toJson());expect(restored.entries.single.receivedMmk,10000000);expect(restored.entries.single.referenceRate,133689840);
 });
 test('Invalid backups, future actual entries, impossible dates, duplicated IDs and overlapping periods are rejected',(){
  final store=BudgetStore(clock:()=>today);final data=BudgetData(entries:[row('a',BudgetKind.income,10000)],plans:[period]);
  final bad=[
   <String,dynamic>{'kind':'exchange_records','schema_version':1},
   {...data.toJson(),'entries':[false]},
   {...data.toJson(),'entries':[row('future',BudgetKind.income,10000,day:'2026-10-19').toJson()]},
   {...data.toJson(),'entries':[row('bad',BudgetKind.income,10000,day:'2026-02-30').toJson()]},
   {...data.toJson(),'entries':[...data.entries.map((e)=>e.toJson()),...data.entries.map((e)=>e.toJson())]},
   {...data.toJson(),'plans':[period.toJson(),const BudgetPlan(id:'other',start:'2026-10-18',end:'2026-11-18').toJson()]},
   {...data.toJson(),'entries':[row('negative',BudgetKind.expense,-1).toJson()]},
   {...data.toJson(),'entries':[row('mmk-on-income',BudgetKind.income,100,mmk:1000).toJson()]},
  ];
  for(final value in bad){expect(()=>store.decode(jsonEncode(value)),throwsFormatException);}
  expect(()=>store.decode('x'*2000001),throwsFormatException);
 });
 test('Stale saves preserve newer local data and budget backup never touches exchange records',()async{
  final store=BudgetStore(clock:()=>today),prefs=await SharedPreferences.getInstance();await prefs.setString(RecordStore.key,'private exchange records');
  final first=await store.save(BudgetData(entries:[row('a',BudgetKind.income,10000)]),expectedRevision:0);
  final second=await store.save(first.copy(entries:[...first.entries,row('b',BudgetKind.expense,1000)]),expectedRevision:first.revision);
  await expectLater(store.save(first,expectedRevision:first.revision),throwsFormatException);
  expect((await store.load()).toJson(),second.toJson());expect(prefs.getString(RecordStore.key),'private exchange records');
 });
 test('Corrupt/unsupported local data is never silently reset; explicit valid recovery can replace it',()async{
  final store=BudgetStore(clock:()=>today),prefs=await SharedPreferences.getInstance();await prefs.setString(BudgetStore.key,'broken data');
  await expectLater(store.load(),throwsFormatException);await expectLater(store.save(const BudgetData(),expectedRevision:0),throwsFormatException);expect(prefs.getString(BudgetStore.key),'broken data');
  final restored=await store.save(BudgetData(entries:[row('recovered',BudgetKind.income,1000)]),expectedRevision:5,replaceCorrupt:true);expect(restored.revision,6);expect((await store.load()).entries.single.id,'recovered');
 });
}
