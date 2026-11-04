import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'budget_models.dart';
import 'storage_lock.dart';

export 'budget_models.dart';

class BudgetStore {
  static const key='bahtzay_budget_v1', limit=budgetEntryLimit, maxBytes=2000000;
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
  Future<BudgetData> save(BudgetData next,{required int expectedRevision,bool replaceCorrupt=false}) => withStorageLock(key, () async {
    final p=await preferences();await p.reload();final raw=p.getString(key);
    BudgetData current;
    try { current=raw==null?const BudgetData():decode(raw); }
    catch (_) { if(!replaceCorrupt) rethrow; current=BudgetData(revision:expectedRevision); }
    if(current.revision!=expectedRevision) throw const FormatException('ငွေစာရင်း ပြောင်းထားတယ်။ ပြန်ဖတ်ပြီးမှ သိမ်းပေးပါ။');
    final checked=decode(jsonEncode(next.copy(revision:current.revision+1).toJson()));
    final ok=await p.setString(key,jsonEncode(checked.toJson()));
    if(!ok) throw const FormatException('ဖုန်းထဲ သိမ်းမရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။');
    return checked;
  });
  String backup(BudgetData data)=>jsonEncode(data.toJson());
}

