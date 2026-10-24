import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

DateTime budgetToday([DateTime? at]) {
  final thai = (at ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime.utc(thai.year, thai.month, thai.day);
}
String budgetDay(DateTime day) => day.toIso8601String().substring(0, 10);
String budgetMoney(int amount) => amount < 0 ? '-${money(-amount)}' : money(amount);
DateTime parseBudgetDay(dynamic raw) {
  if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) throw const FormatException('ရက်စွဲကို ပြန်စစ်ပေးပါ။');
  final date = DateTime.tryParse('${raw}T00:00:00Z');
  if (date == null || date.year < 2000 || date.year > 2100 || budgetDay(date) != raw) throw const FormatException('ရက်စွဲကို ပြန်စစ်ပေးပါ။');
  return date;
}
const budgetExpenseCategories = {'food':'စားသောက်', 'home':'အခန်းခ / အိမ်စရိတ်', 'travel':'သွားလာရေး', 'study':'ကျောင်း / သင်တန်း', 'phone':'ဖုန်း / အင်တာနက်', 'utilities':'မီးဖိုး / ရေဖိုး', 'shopping':'အဝတ်အစား / အသုံးအဆောင်', 'personal':'တစ်ကိုယ်ရေသုံး', 'documents':'စာရွက်စာတမ်း / ဗီဇာ', 'leisure':'အပန်းဖြေ', 'bills':'ဖုန်း / မီတာခ', 'health':'ကျန်းမာရေး', 'other':'အခြား'};
const budgetIncomeCategories = {'salary':'လစာ', 'daily':'နေ့စား', 'overtime':'OT', 'tips':'Tip / အပိုရငွေ', 'allowance':'မုန့်ဖိုး / ထောက်ပံ့ငွေ', 'other':'အခြား'};
enum BudgetKind { income, expense, remittance }
String budgetKindName(BudgetKind kind) => switch (kind) { BudgetKind.income => 'ဝင်ငွေ', BudgetKind.expense => 'သုံးငွေ', BudgetKind.remittance => 'အိမ်ပို့ပြီးငွေ' };

class BudgetEntry {
  final String id, day, category, note;
  final BudgetKind kind;
  final int amount;
  final bool fromFixed;
  final int? receivedMmk, referenceRate;
  final String? referenceAt;
  const BudgetEntry({required this.id, required this.day, required this.kind, required this.amount, required this.category, this.note = '', this.fromFixed = false, this.receivedMmk, this.referenceRate, this.referenceAt});
  String get label => kind == BudgetKind.remittance ? 'အိမ်ပို့ပြီးငွေ' : (kind == BudgetKind.income ? budgetIncomeCategories : budgetExpenseCategories)[category] ?? 'အခြား';
  factory BudgetEntry.fromJson(Map<String, dynamic> j, {DateTime? today}) {
    final id = j['id'], day = j['day'], amount = j['amount_minor'], category = j['category'], note = j['note'];
    final kind = BudgetKind.values.where((k) => k.name == j['kind']).firstOrNull;
    if (id is! String || id.isEmpty || id.length > 100 || kind == null || amount is! int || amount <= 0 || amount > maxMoneyMinor || note is! String || note.length > 180 || j['from_fixed'] is! bool) throw const FormatException('ငွေစာရင်းအချက်အလက် မပြည့်စုံပါ။');
    if (parseBudgetDay(day).isAfter(today ?? budgetToday())) throw const FormatException('တကယ်ဝင်ပြီး / သုံးပြီးတဲ့ငွေကိုပဲ ရက်စွဲနဲ့ မှတ်ပေးပါ။');
    final allowed = kind == BudgetKind.income ? budgetIncomeCategories.keys : kind == BudgetKind.expense ? budgetExpenseCategories.keys : ['family'];
    if (category is! String || !allowed.contains(category) || j['from_fixed'] == true && kind != BudgetKind.expense) throw const FormatException('အသုံးစရိတ်အမျိုးအစားကို ပြန်စစ်ပေးပါ။');
    final received = j['received_mmk_minor'], rate = j['reference_rate_micros'], observed = j['reference_at'];
    if (received != null && (kind != BudgetKind.remittance || received is! int || received <= 0 || received > maxMoneyMinor)) throw const FormatException('ရထားတဲ့ ကျပ်ပမာဏကို ပြန်စစ်ပေးပါ။');
    if (rate != null || observed != null) {
      if (kind != BudgetKind.remittance || rate is! int || rate < 1 || rate > 1000000000000 || observed is! String || DateTime.tryParse(observed) == null) throw const FormatException('မှတ်ထားတဲ့ ငွေလဲနှုန်း မပြည့်စုံပါ။');
    }
    return BudgetEntry(id:id, day:day as String, kind:kind, amount:amount, category:category, note:note, fromFixed:j['from_fixed'] as bool, receivedMmk:received as int?, referenceRate:rate as int?, referenceAt:observed as String?);
  }
  Map<String, dynamic> toJson() => {'id':id, 'day':day, 'kind':kind.name, 'amount_minor':amount, 'category':category, 'note':note, 'from_fixed':fromFixed, if(receivedMmk != null)'received_mmk_minor':receivedMmk, if(referenceRate != null)'reference_rate_micros':referenceRate, if(referenceAt != null)'reference_at':referenceAt};
}

class BudgetPlan {
  final String id, start, end;
  final int fixed, home, savings;
  const BudgetPlan({required this.id, required this.start, required this.end, this.fixed = 0, this.home = 0, this.savings = 0});
  bool contains(String day) => day.compareTo(start) >= 0 && day.compareTo(end) < 0;
  factory BudgetPlan.fromJson(Map<String, dynamic> j) {
    final id=j['id'], start=j['start'], end=j['end'];
    if(id is! String || id.isEmpty || id.length > 100) throw const FormatException('အစီအစဉ်အချက်အလက် မပြည့်စုံပါ။');
    final span=parseBudgetDay(end).difference(parseBudgetDay(start)).inDays;
    if(span < 1 || span > 366) throw const FormatException('အစီအစဉ်ရက်တွေကို ပြန်စစ်ပေးပါ။ အများဆုံး ၁ နှစ်အထိ စီမံနိုင်တယ်။');
    for(final key in ['fixed_minor','home_minor','savings_minor']) { final n=j[key]; if(n is! int || n < 0 || n > maxMoneyMinor) throw const FormatException('ဖယ်ထားမယ့်ငွေကို ပြန်စစ်ပေးပါ။'); }
    return BudgetPlan(id:id, start:start as String, end:end as String, fixed:j['fixed_minor'] as int, home:j['home_minor'] as int, savings:j['savings_minor'] as int);
  }
  Map<String, dynamic> toJson() => {'id':id,'start':start,'end':end,'fixed_minor':fixed,'home_minor':home,'savings_minor':savings};
}

class BudgetData {
  final int revision, opening;
  final List<BudgetEntry> entries;
  final List<BudgetPlan> plans;
  const BudgetData({this.revision=0, this.opening=0, this.entries=const [], this.plans=const []});
  BudgetData copy({int? revision, int? opening, List<BudgetEntry>? entries, List<BudgetPlan>? plans}) => BudgetData(revision:revision ?? this.revision, opening:opening ?? this.opening, entries:entries ?? this.entries, plans:plans ?? this.plans);
  BudgetPlan? planAt(DateTime today) {
    final day=budgetDay(today), sorted=[...plans]..sort((a,b)=>b.start.compareTo(a.start));
    return sorted.where((p)=>p.contains(day)).firstOrNull ?? sorted.where((p)=>p.start.compareTo(day)<=0).firstOrNull ?? sorted.lastOrNull;
  }
  factory BudgetData.fromJson(Map<String, dynamic> j, {DateTime? today}) {
    final opening=j['opening_minor'], revision=j['revision'];
    if(j['kind']!='bahtzay_budget' || j['schema_version']!=1 || opening is! int || opening<0 || opening>maxMoneyMinor || revision is! int || revision<0 || revision>maxMoneyMinor || j['entries'] is! List || j['plans'] is! List) throw const FormatException('ဘတ်ဈေး app ရဲ့ ကိုယ့်ငွေစာရင်း backup ဖိုင်ကို ရွေးပေးပါ။');
    final rows=j['entries'] as List, periods=j['plans'] as List;
    if(rows.length>BudgetStore.limit || periods.length>120) throw const FormatException('သိမ်းနိုင်တဲ့ စာရင်းအရေအတွက် ကျော်နေပါတယ်။');
    if(rows.any((r)=>r is! Map<String,dynamic>) || periods.any((r)=>r is! Map<String,dynamic>)) throw const FormatException('Backup ဖိုင်ထဲက စာရင်း မပြည့်စုံပါ။');
    final entries=rows.map((r)=>BudgetEntry.fromJson(r as Map<String,dynamic>,today:today)).toList();
    final plans=periods.map((r)=>BudgetPlan.fromJson(r as Map<String,dynamic>)).toList()..sort((a,b)=>a.start.compareTo(b.start));
    if(entries.map((r)=>r.id).toSet().length!=entries.length || plans.map((p)=>p.id).toSet().length!=plans.length) throw const FormatException('ဖိုင်ထဲမှာ မှတ်တမ်းနံပါတ် ထပ်နေပါတယ်။');
    for(var i=1;i<plans.length;i++) { if(plans[i].start.compareTo(plans[i-1].end)<0) throw const FormatException('အစီအစဉ်ရက်တွေ ထပ်နေပါတယ်။ အရင်ကာလပြီးမှ အသစ်စပေးပါ။'); }
    return BudgetData(revision:revision,opening:opening,entries:entries,plans:plans);
  }
  Map<String,dynamic> toJson()=>{'kind':'bahtzay_budget','schema_version':1,'revision':revision,'opening_minor':opening,'entries':entries.map((e)=>e.toJson()).toList(),'plans':plans.map((p)=>p.toJson()).toList()};
}

class BudgetSummary {
  final BudgetData data;
  final DateTime today;
  late final BudgetPlan? plan=data.planAt(today);
  BudgetSummary(this.data,this.today);
  int get balance => data.opening + data.entries.fold<int>(0,(sum,e)=>sum+(e.kind==BudgetKind.income?e.amount:-e.amount));
  int paid(BudgetKind kind,{bool fixed=false}) {
    if(plan==null)return 0;
    // Outstanding bills can still be paid after a payday is missed. Carry the
    // latest expired plan through today until another period takes effect.
    final day=budgetDay(today);
    final end=plan!.end.compareTo(day)<=0?budgetDay(today.add(const Duration(days:1))):plan!.end;
    return data.entries.where((e)=>e.kind==kind && e.day.compareTo(plan!.start)>=0 && e.day.compareTo(end)<0 && (!fixed || e.fromFixed)).fold<int>(0,(sum,e)=>sum+e.amount);
  }
  int get fixedLeft => ((plan?.fixed ?? 0)-paid(BudgetKind.expense,fixed:true)).clamp(0,maxMoneyMinor).toInt();
  int get homeLeft => ((plan?.home ?? 0)-paid(BudgetKind.remittance)).clamp(0,maxMoneyMinor).toInt();
  int get protected => fixedLeft+homeLeft+(plan?.savings ?? 0);
  int get available => balance-protected;
  int? get daysLeft => plan==null || !plan!.contains(budgetDay(today))?null:parseBudgetDay(plan!.end).difference(today).inDays;
  int? get daily => daysLeft==null?null:(available<0?0:available)~/daysLeft!;
}

class BudgetMonth {
  final List<BudgetEntry> entries;
  BudgetMonth(BudgetData data,DateTime month):entries=data.entries.where((e)=>e.day.startsWith(budgetDay(month).substring(0,7))).toList()..sort((a,b)=>b.day.compareTo(a.day));
  int total(BudgetKind kind)=>entries.where((e)=>e.kind==kind).fold<int>(0,(sum,e)=>sum+e.amount);
  int get out => total(BudgetKind.expense)+total(BudgetKind.remittance);
  Map<String,int> get categories {
    final sums=<String,int>{};
    for(final e in entries.where((e)=>e.kind!=BudgetKind.income)) { final label=e.label;sums[label]=(sums[label]??0)+e.amount; }
    return Map.fromEntries(sums.entries.toList()..sort((a,b)=>b.value.compareTo(a.value)));
  }
}

class BudgetStore {
  static const key='bahtzay_budget_v1', limit=2000, maxBytes=2000000;
  final Future<SharedPreferences> Function() preferences;
  final DateTime Function() clock;
  BudgetStore({Future<SharedPreferences> Function()? preferences,DateTime Function()? clock}):preferences=preferences??SharedPreferences.getInstance,clock=clock??DateTime.now;
  BudgetData decode(String raw) {
    if(raw.length>maxBytes || utf8.encode(raw).length>maxBytes) throw const FormatException('Backup ဖိုင်ကြီးလွန်းနေပါတယ်။');
    final value=jsonDecode(raw);
    if(value is! Map<String,dynamic>) throw const FormatException('ငွေစာရင်းဖိုင်ကို ပြန်စစ်ပေးပါ။');
    return BudgetData.fromJson(value,today:budgetToday(clock()));
  }
  Future<BudgetData> load() async {
    final p=await preferences();await p.reload();
    final raw=p.getString(key);
    return raw==null?const BudgetData():decode(raw);
  }
  Future<BudgetData> save(BudgetData next,{required int expectedRevision,bool replaceCorrupt=false}) async {
    final p=await preferences();await p.reload();final raw=p.getString(key);
    BudgetData current;
    try { current=raw==null?const BudgetData():decode(raw); }
    catch (_) { if(!replaceCorrupt) rethrow; current=BudgetData(revision:expectedRevision); }
    if(current.revision!=expectedRevision) throw const FormatException('ငွေစာရင်း ပြောင်းထားတယ်။ ပြန်ဖတ်ပြီးမှ သိမ်းပေးပါ။');
    final checked=decode(jsonEncode(next.copy(revision:current.revision+1).toJson()));
    final ok=await p.setString(key,jsonEncode(checked.toJson()));
    if(!ok) throw const FormatException('ဖုန်းထဲ သိမ်းမရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။');
    return checked;
  }
  String backup(BudgetData data)=>jsonEncode(data.toJson());
}
