import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'user_language.dart' show Text, uiText;
import 'package:flutter/services.dart';
import 'budget.dart';
import 'complete_backup_page.dart';
import 'models.dart';
import 'platform_files.dart';
import 'trend_card.dart' show bangkokLabel;

String _id() => '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1000000000)}';
String _editMoney(int n) => n == 0 ? '' : (n / 100).toStringAsFixed(2);
int _amount(String text, {bool optional=false}) {
  final value=parseMoney(text.trim().isEmpty && optional ? '0' : text,allowZero:optional);
  if(value==null) throw const FormatException('ငွေပမာဏကို ပြန်စစ်ပေးပါ။ ဒသမ ၂ နေရာအထိ ထည့်နိုင်တယ်။');
  return value;
}

class BudgetPage extends StatefulWidget {
  final BudgetStore? store;
  final ExchangeQuote? quote;
  final DateTime? today;
  const BudgetPage({super.key,this.store,this.quote,this.today});
  @override
  State<BudgetPage> createState()=>_BudgetPageState();
}
class _BudgetPageState extends State<BudgetPage> with WidgetsBindingObserver {
  late final store=widget.store??BudgetStore();
  DateTime get today=>widget.today??budgetToday();
  late DateTime month=DateTime.utc(today.year,today.month);
  BudgetData data=const BudgetData();
  bool loading=true,busy=false,editing=false,ready=false;
  int loadId=0;
  String? error;
  ExchangeQuote? get quote=>widget.quote?.direction==ExchangeDirection.thbMmk?widget.quote:null;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);reload();}
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&!busy&&!editing)reload();}
  String errorText(Object e)=>e is FormatException?e.message:'ဖုန်းထဲက ငွေစာရင်းကို ဖတ်/သိမ်းမရသေးဘူး။ ပြန်စမ်းပေးပါ။';
  void message(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
  Future<void> reload() async {
    if(busy||editing)return;
    final id=++loadId;
    setState((){loading=true;error=null;});
    try{final value=await store.load();if(mounted&&id==loadId)setState((){data=value;ready=true;});}
    catch(e){if(mounted&&id==loadId)setState((){error=errorText(e);ready=false;});}
    finally{if(mounted&&id==loadId)setState(()=>loading=false);}
  }
  Future<void> persist(BudgetData next,{bool recovery=false}) async {
    if(busy)throw const FormatException('သိမ်းနေပါတယ်။ ခဏစောင့်ပေးပါ။');
    setState(()=>busy=true);
    try{
      final value=await store.save(next,expectedRevision:data.revision,replaceCorrupt:recovery);
      if(mounted)setState((){data=value;ready=true;error=null;});
    }finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> entry(BudgetKind kind,{BudgetEntry? original}) async {
    if(!ready||loading||busy||editing)return;
    editing=true;
    final before=data;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>BudgetEntryEditor(
      kind:kind,initial:original,quote:quote,today:today,
      onSave:(value)async{
        final rows=[value,...before.entries.where((e)=>e.id!=value.id)];
        await persist(before.copy(entries:rows));
        if(mounted)setState(()=>month=DateTime.utc(parseBudgetDay(value.day).year,parseBudgetDay(value.day).month));
      },
    )));
    editing=false;
  }
  Future<void> plan({bool create=false,BudgetPlan? selected}) async {
    if(!ready||loading||busy||editing)return;
    editing=true;
    final before=data,current=BudgetSummary(data,today).plan;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>BudgetPlanEditor(
      data:before,initial:create?null:selected??current,today:today,
      onSave:(opening,value)async=>persist(before.copy(opening:opening,plans:[value,...before.plans.where((p)=>p.id!=value.id)])),
    )));
    editing=false;
  }
  Future<void> remove(BudgetEntry value) async {
    if(loading||busy||editing)return;
    editing=true;
    final before=data;
    try{
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('ဒီမှတ်တမ်းကို ဖျက်မလား?'),content:Text('${value.day}\n${value.label} · ${money(value.amount)} ဘတ်\n\nလက်ကျန်နဲ့ ဖယ်ထားငွေကို ပြန်တွက်ပေးမယ်။'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('မဖျက်တော့')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ဖျက်မယ်'))],
    ));
    if(!mounted||confirmed!=true)return;
    try{await persist(before.copy(entries:before.entries.where((e)=>e.id!=value.id).toList()));message('မှတ်တမ်း ဖျက်ပြီးပြီ။');}catch(e){message(errorText(e));}
    }finally{editing=false;}
  }
  Future<void> removePlan(BudgetPlan value)async{
    if(loading||busy||editing)return;
    editing=true;
    final before=data;
    try{
      final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('ဒီအစီအစဉ်ကို ဖျက်မလား?'),content:Text('${value.start} မှ ${value.end} မတိုင်မီ\n\nဝင်/ထွက်ငွေမှတ်တမ်းတွေ မပျက်ဘဲ ဖယ်ထားငွေကို ပြန်တွက်ပေးမယ်။'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('မဖျက်တော့')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('ဖျက်မယ်'))]));
      if(confirmed==true&&mounted)await persist(before.copy(plans:before.plans.where((p)=>p.id!=value.id).toList()));
    }catch(e){message(errorText(e));}finally{editing=false;}
  }
  Future<void> backup() async {
    if(!ready)return;
    final raw=store.backup(data);
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('ငွေစာရင်း Backup သိမ်းမယ်'),
      content:Text('မှတ်တမ်း ${data.entries.length} ခုနဲ့ အစီအစဉ် ${data.plans.length} ခု ပါမယ်။\n\nဒီဖိုင်မှာ ကိုယ့်ငွေစာရင်းတွေ ပါပါတယ်။ Browser data ဖျက်တာ၊ ဖုန်းပြောင်းတာမတိုင်မီ သိမ်းထားနိုင်တယ်။'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('ပိတ်မယ်')),
        TextButton(onPressed:()async{try{await Clipboard.setData(ClipboardData(text:raw));if(mounted)message('Backup စာကို ကူးထားပြီ။ ဖိုင် ဒါမှမဟုတ် ကိုယ်ပိုင်နေရာမှာ သိမ်းထားပါ။');}catch(e){message(errorText(e));}},child:const Text('Backup စာ ကူးမယ်')),
        if(kIsWeb)FilledButton(onPressed:(){downloadBytes(utf8.encode(raw),'bahtzay-budget-${budgetDay(today)}.json','application/json');Navigator.pop(ctx);},child:const Text('Backup ဖိုင်ယူမယ်')),
      ],
    ));
  }
  Future<void> restore() async {
    if(busy||editing)return;
    editing=true;
    final before=data,wasReady=ready;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>BudgetRestorePage(
      store:store,currentCount:before.entries.length,
      onRestore:(value)async{await persist(value.copy(revision:before.revision),recovery:!wasReady);message('Backup မှတ်တမ်း ${value.entries.length} ခု ပြန်ထည့်ပြီးပြီ။');},
    )));
    editing=false;
  }
  Widget card(Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:child));
  Widget line(String label,int amount)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Wrap(spacing:10,runSpacing:4,alignment:WrapAlignment.spaceBetween,children:[Text(label),Text('${budgetMoney(amount)} ဘတ်',style:const TextStyle(fontWeight:FontWeight.w700))]));
  @override
  Widget build(BuildContext context){
    final scheme=Theme.of(context).colorScheme,summary=BudgetSummary(data,today),report=BudgetMonth(data,month);
    final current=summary.plan;
    final estimate=quote==null||summary.homeLeft<=0?0:quote!.payout(summary.homeLeft);
    return Scaffold(
      appBar:AppBar(title:const Text('ကိုယ့်ငွေစာရင်း'),actions:[
        IconButton(tooltip: uiText(context, 'စာရင်းပြန်ဖတ်မယ်'),onPressed:loading||busy?null:reload,icon:const Icon(Icons.refresh)),
        PopupMenuButton<String>(tooltip: uiText(context, 'Backup / အကူအညီ'),onSelected:(v){if(v=='export')backup();if(v=='import')restore();if(v=='complete'){Navigator.of(context).push<void>(MaterialPageRoute(builder:(_)=>const CompleteBackupPage())).then((_){if(mounted)reload();});}if(v=='help')showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('ကိုယ့်ငွေကို စီမံမယ်'),content:const SingleChildScrollView(child:Text('ရပြီးသားဝင်ငွေနဲ့ တကယ်သုံးပြီးတဲ့ငွေကို ဘတ်နဲ့ မှတ်ပါ။ အိမ်မှာတကယ်ရတဲ့ ကျပ်ပမာဏကိုလည်း တွဲမှတ်နိုင်တယ်။\n\nအခန်းခ/မီတာခ ပေးတဲ့အခါ “ဖယ်ထားငွေထဲက ပေးတာ” ကို ရွေးရင် ပေးရန်ကျန်ငွေကိုပါ လျှော့ပြမယ်။ အိမ်ပို့ပြီးငွေကိုတော့ အိမ်ပို့ရန်ကျန်ငွေထဲက အလိုအလျောက် လျှော့ပေးမယ်။\n\nစုငွေကို အစီအစဉ်မှာ ဖယ်ထားနိုင်တယ်။ ရက်ကျော်နေတဲ့အစီအစဉ်ရဲ့ ဖယ်ထားငွေကိုလည်း အသစ်စီမံတဲ့အထိ ဆက်ဖယ်ထားပေးမယ်။\n\nဒီစာရင်းကို ဖုန်း/Browser ထဲမှာပဲ သိမ်းတယ်။ Admin ကို မပို့ပါဘူး။ Backup ဖိုင်ကို ကိုယ်တိုင် ထုတ်သိမ်းထားပါ။')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('နားလည်ပြီ'))]));},itemBuilder:(_)=>[
          PopupMenuItem(value:'export',enabled:ready,child:const Text('Backup သိမ်းမယ်')),
          const PopupMenuItem(value:'complete',child:Text('မှတ်တမ်းအားလုံး Backup')),
          const PopupMenuItem(value:'import',child:Text('Backup ပြန်ထည့်မယ်')),
          const PopupMenuItem(value:'help',child:Text('အသုံးပြုနည်း / ကိုယ်ရေးအချက်အလက်')),
        ]),
      ]),
      floatingActionButton:ready?FloatingActionButton.extended(key:const ValueKey('budget_add_expense'),onPressed:busy?null:()=>entry(BudgetKind.expense),icon:const Icon(Icons.add),label:const Text('သုံးငွေမှတ်မယ်')):null,
      body:RefreshIndicator(onRefresh:reload,child:ListView(padding:const EdgeInsets.fromLTRB(14,8,14,110),children:[
        if(loading)const LinearProgressIndicator(),
        if(error!=null)card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(error!),const Text('အရင်ငွေစာရင်းကို အစားမထိုးထားပါဘူး။'),Wrap(spacing:8,children:[TextButton(onPressed:reload,child:const Text('ပြန်ဖတ်မယ်')),TextButton(onPressed:restore,child:const Text('Backup ပြန်ထည့်မယ်'))])])),
        if(ready)...[
          card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('ယနေ့ လက်ကျန်',style:TextStyle(fontWeight:FontWeight.w700)),
            Text('${budgetMoney(summary.balance)} ဘတ်',key:const ValueKey('budget_balance'),style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800,color:scheme.primary)),
            const SizedBox(height:8),line('ဖယ်ထားငွေ',summary.protected),
            line('ဖယ်ထားပြီး သုံးလို့ရမယ့်ငွေ',summary.available<0?0:summary.available),
            if(summary.available<0)Text('ဖယ်ထားဖို့ ${budgetMoney(-summary.available)} ဘတ် လိုနေသေးတယ်။',style:TextStyle(color:scheme.error)),
            if(summary.daily!=null)Text('နောက်ဝင်ငွေရမယ့်ရက်အထိ တစ်ရက် ${money(summary.daily!)} ဘတ်ခန့် သုံးနိုင်တယ်။',key:const ValueKey('budget_daily'),style:const TextStyle(height:1.8)),
            const SizedBox(height:8),const Text('ရပြီးသားငွေနဲ့ သွင်းထားတဲ့စာရင်းအပေါ် အခြေခံထားတာပါ။ ထပ်ဝင်မယ့်ငွေ မပါသေးပါဘူး။',style:TextStyle(fontSize:12,height:1.8)),
            Wrap(spacing:8,runSpacing:4,children:[OutlinedButton.icon(key:const ValueKey('budget_add_income'),onPressed:busy?null:()=>entry(BudgetKind.income),icon:const Icon(Icons.add),label:const Text('ဝင်ငွေမှတ်မယ်')),TextButton.icon(key:const ValueKey('budget_add_remittance'),onPressed:busy?null:()=>entry(BudgetKind.remittance),icon:const Icon(Icons.send_outlined),label:const Text('အိမ်ပို့ပြီးတာ မှတ်မယ်'))]),
          ])),
          card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('ကြိုဖယ်ထားမယ့်ငွေ',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700)),
            if(current==null)const Text('အခုရှိငွေ၊ နောက်ဝင်ငွေရမယ့်ရက်နဲ့ ပေးဖို့ရှိတာတွေကို စီမံထားနိုင်တယ်။',style:TextStyle(height:1.8))
            else...[
              Text('${current.start} မှ ${current.end} မတိုင်မီ',style:const TextStyle(fontSize:12)),
              if(summary.daysLeft==null)const Text('ဒီနေ့နဲ့ကိုက်တဲ့ ကာလအသစ်ကို စီမံပေးပါ။ ဖယ်ထားငွေတွေကိုတော့ ဆက်ဖယ်ထားပေးထားတယ်။',style:TextStyle(height:1.8)),
              line('ပုံမှန်ပေးစရာ ကျန်ငွေ',summary.fixedLeft),line('အိမ်ပို့ရန် ကျန်ငွေ',summary.homeLeft),line('စုဖို့ ဖယ်ထားငွေ',current.savings),
              if(estimate>0)...[
                Text('အိမ်ပို့ရန်ကျန်ငွေနဲ့ ကျပ် ${money(estimate)} ခန့် ရနိုင်တယ်။',key:const ValueKey('budget_remittance_estimate'),style:TextStyle(color:scheme.primary,fontWeight:FontWeight.w600,height:1.8)),
                Text('${quoteRateLabel(quote!)} · ${bangkokLabel(quote!.observedAt)} ထိုင်းအချိန်${quote!.activeAt(DateTime.now())?'':' · နောက်ဆုံးရထားတဲ့ဈေး'}',style:const TextStyle(fontSize:12,height:1.8)),
              ],
            ],
            Wrap(spacing:8,runSpacing:4,children:[TextButton.icon(key:const ValueKey('budget_plan'),onPressed:busy?null:()=>plan(),icon:const Icon(Icons.tune),label:Text(current==null?'ငွေစီမံမယ်':'အစီအစဉ် ပြင်မယ်')),if(current!=null)TextButton(onPressed:busy?null:()=>plan(create:true),child:const Text('ကာလအသစ် စီမံမယ်'))]),
            if(data.plans.isNotEmpty)ExpansionTile(tilePadding:EdgeInsets.zero,title:Text('သိမ်းထားတဲ့အစီအစဉ်များ · ${data.plans.length} ခု',style:const TextStyle(fontSize:13)),children:[for(final p in [...data.plans]..sort((a,b)=>b.start.compareTo(a.start)))Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${p.start} → ${p.end} မတိုင်မီ'),Text('${money(p.fixed+p.home+p.savings)} ဘတ် ဖယ်ထားဖို့ စီမံထားတယ်။',style:const TextStyle(fontSize:12)),Wrap(spacing:8,children:[TextButton(onPressed:busy?null:()=>plan(selected:p),child:const Text('ဒီကာလ ပြင်မယ်')),TextButton(onPressed:busy?null:()=>removePlan(p),child:const Text('ဒီအစီအစဉ် ဖျက်မယ်'))])]))]),
          ])),
          card(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Row(children:[IconButton(tooltip: uiText(context, 'ယခင်လ'),onPressed:month.year<=2000&&month.month==1?null:()=>setState(()=>month=DateTime.utc(month.year,month.month-1)),icon:const Icon(Icons.chevron_left)),Expanded(child:Text('${month.year} / ${month.month} စာရင်း',textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700))),IconButton(tooltip: uiText(context, 'နောက်လ'),onPressed:month.year==today.year&&month.month==today.month?null:()=>setState(()=>month=DateTime.utc(month.year,month.month+1)),icon:const Icon(Icons.chevron_right))]),
            line('ဒီလ ဝင်ငွေ',report.total(BudgetKind.income)),line('ဒီလ သုံးငွေ',report.total(BudgetKind.expense)),line('ဒီလ အိမ်ပို့ပြီးငွေ',report.total(BudgetKind.remittance)),
            const Divider(),const Text('ဒီလ ထွက်ငွေ ဘာတွေအတွက် သုံးထားလဲ?',style:TextStyle(fontWeight:FontWeight.w700)),
            if(report.out==0)const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Text('ဒီလအတွက် သုံးငွေ မမှတ်ရသေးဘူး။')),
            for(final category in report.categories.entries)Padding(padding:const EdgeInsets.only(top:12),child:Semantics(label:'${category.key} ${money(category.value)} ဘတ်',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[line(category.key,category.value),LinearProgressIndicator(value:category.value/report.out,minHeight:9,borderRadius:BorderRadius.circular(9),semanticsLabel:category.key)]))),
            const SizedBox(height:12),const Text('ကျပ်ရငွေကို ဘတ်သုံးငွေနဲ့ ထပ်ပေါင်းမထားပါဘူး။ အိမ်ပို့ပြီးငွေကို ဘတ်ထွက်ငွေအဖြစ် တစ်ကြိမ်ပဲ တွက်ထားတယ်။',style:TextStyle(fontSize:12,height:1.8)),
          ])),
          Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text('ဒီလ မှတ်တမ်း ${report.entries.length} ခု',style:const TextStyle(fontWeight:FontWeight.w700))),
          if(report.entries.isEmpty)const Text('အောက်က “သုံးငွေမှတ်မယ်” ဒါမှမဟုတ် “ဝင်ငွေမှတ်မယ်” ကနေ စမှတ်နိုင်တယ်။',style:TextStyle(height:1.8)),
          for(final e in report.entries)Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(e.label,style:const TextStyle(fontWeight:FontWeight.w700)),Text('${e.kind==BudgetKind.income?'+':'−'}${money(e.amount)} ဘတ်',key:ValueKey('budget_entry_${e.id}'),style:TextStyle(fontSize:20,fontWeight:FontWeight.w700,color:e.kind==BudgetKind.income?scheme.primary:scheme.onSurface)),Text(e.day,style:const TextStyle(fontSize:12)),if(e.receivedMmk!=null)Text('အိမ်မှာရငွေ ${money(e.receivedMmk!)} ကျပ်'),if(e.fromFixed)const Text('ပုံမှန်ပေးစရာ ဖယ်ထားငွေထဲက သုံးထားတယ်။',style:TextStyle(fontSize:12)),if(e.note.isNotEmpty)Text(e.note),if(e.referenceRate!=null)Text('မှတ်ချိန်က ရည်ညွှန်းဈေး · ${referenceRateText(e.referenceRate!)} ဘတ် / ကျပ် ၁ သိန်း\n${bangkokLabel(DateTime.parse(e.referenceAt!))} ထိုင်းအချိန်',style:const TextStyle(fontSize:12,height:1.8))])),PopupMenuButton<String>(key:ValueKey('budget_menu_${e.id}'),tooltip: uiText(context, 'မှတ်တမ်း ပြင် / ဖျက်'),onSelected:(v){if(v=='edit')entry(e.kind,original:e);if(v=='delete')remove(e);},itemBuilder:(_)=>[const PopupMenuItem(value:'edit',child:Text('ပြင်မယ်')),const PopupMenuItem(value:'delete',child:Text('ဖျက်မယ်'))])]))),
        ],
      ])),
    );
  }
}

class BudgetEntryEditor extends StatefulWidget {
  final BudgetKind kind;
  final BudgetEntry? initial;
  final ExchangeQuote? quote;
  final DateTime today;
  final Future<void> Function(BudgetEntry) onSave;
  const BudgetEntryEditor({super.key,required this.kind,this.initial,this.quote,required this.today,required this.onSave});
  @override
  State<BudgetEntryEditor> createState()=>_BudgetEntryEditorState();
}
class _BudgetEntryEditorState extends State<BudgetEntryEditor> {
  late final amount=TextEditingController(text:widget.initial==null?'':_editMoney(widget.initial!.amount));
  late final note=TextEditingController(text:widget.initial?.note??'');
  late final mmk=TextEditingController(text:widget.initial?.receivedMmk==null?'':_editMoney(widget.initial!.receivedMmk!));
  late String category=widget.initial?.category??(widget.kind==BudgetKind.income?'salary':widget.kind==BudgetKind.expense?'food':'family');
  late String day=widget.initial?.day??budgetDay(widget.today);
  late bool fixed=widget.initial?.fromFixed??false;
  bool busy=false;
  String? error;
  @override
  void dispose(){amount.dispose();note.dispose();mmk.dispose();super.dispose();}
  Future<void> save() async {
    if(busy)return;
    FocusScope.of(context).unfocus();setState((){busy=true;error=null;});
    try{
      final reference=widget.kind==BudgetKind.remittance&&widget.initial==null?(widget.quote?.direction==ExchangeDirection.thbMmk?widget.quote:null):null;
      final e=BudgetEntry(id:widget.initial?.id??_id(),day:day,kind:widget.kind,amount:_amount(amount.text),category:category,note:note.text.trim(),fromFixed:widget.kind==BudgetKind.expense&&fixed,receivedMmk:widget.kind==BudgetKind.remittance&&mmk.text.trim().isNotEmpty?_amount(mmk.text):null,referenceRate:widget.initial?.referenceRate??reference?.rateMicros,referenceAt:widget.initial?.referenceAt??reference?.observedAt.toUtc().toIso8601String());
      BudgetEntry.fromJson(e.toJson(),today:widget.today);
      await widget.onSave(e);
      if(mounted)Navigator.pop(context);
    }catch(e){if(mounted)setState(()=>error=e is FormatException?e.message:'သိမ်းမရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context){
    final categories=widget.kind==BudgetKind.income?budgetIncomeCategories:budgetExpenseCategories;
    return Scaffold(appBar:AppBar(title:Text('${budgetKindName(widget.kind)} ${widget.initial==null?'မှတ်မယ်':'ပြင်မယ်'}')),body:ListView(padding:const EdgeInsets.all(20),children:[
      TextField(key:const ValueKey('budget_amount'),controller:amount,enabled:!busy,keyboardType:const TextInputType.numberWithOptions(decimal:true),style:const TextStyle(fontSize:28,fontWeight:FontWeight.w700),decoration:InputDecoration(labelText: uiText(context, 'ဘတ်ပမာဏ'),hintText: uiText(context, 'ဥပမာ 50')),onChanged:(_)=>setState((){})),
      const SizedBox(height:18),
      if(widget.kind!=BudgetKind.remittance)DropdownButtonFormField<String>(initialValue:category,isExpanded:true,decoration:InputDecoration(labelText: uiText(context, 'အမျိုးအစား')),items:categories.entries.map((c)=>DropdownMenuItem(value:c.key,child:Text(c.value))).toList(),onChanged:busy?null:(v){if(v!=null)setState((){category=v;if(widget.initial==null)fixed=v=='home'||v=='bills';});}),
      if(widget.kind==BudgetKind.expense)CheckboxListTile(key:const ValueKey('budget_from_fixed'),contentPadding:EdgeInsets.zero,value:fixed,onChanged:busy?null:(v)=>setState(()=>fixed=v??false),title:const Text('ပုံမှန်ပေးစရာ ဖယ်ထားငွေထဲက ပေးတာ'),subtitle:const Text('အခန်းခ/မီတာခလို ပေးပြီးသမျှအတွက် ပေးရန်ကျန်ငွေကိုပါ လျှော့ပြမယ်။')),
      if(widget.kind==BudgetKind.remittance)...[
        const Text('တကယ်လွှဲပြီးတာကို မှတ်ထားတာပါ။ ဒီနေရာကနေ ငွေလွှဲပေးတာ မဟုတ်ပါဘူး။',style:TextStyle(height:1.8)),
        const SizedBox(height:16),TextField(key:const ValueKey('budget_received_mmk'),controller:mmk,enabled:!busy,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText: uiText(context, 'အိမ်မှာ တကယ်ရတဲ့ ကျပ်ငွေ (သိမှဖြည့်)'),hintText: uiText(context, 'ဥပမာ 100000'))),
      ],
      const SizedBox(height:16),OutlinedButton.icon(key:const ValueKey('budget_entry_date'),onPressed:busy?null:()async{final value=await showDatePicker(context:context,initialDate:parseBudgetDay(day),firstDate:DateTime(2000),lastDate:widget.today,helpText:'တကယ်ဝင်ပြီး / သုံးပြီးတဲ့ရက်');if(value!=null&&mounted)setState(()=>day=budgetDay(DateTime.utc(value.year,value.month,value.day)));},icon:const Icon(Icons.calendar_month),label:Text('ရက်စွဲ · $day')),
      const SizedBox(height:16),TextField(key:const ValueKey('budget_note'),controller:note,enabled:!busy,maxLength:180,maxLines:2,decoration:InputDecoration(labelText: uiText(context, 'မှတ်ချက် (ရေးချင်မှ)'),hintText: uiText(context, 'ဥပမာ နေ့လယ်စာ / ဒီလအခန်းခ'))),
      if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error,height:1.8))),
      FilledButton.icon(key:const ValueKey('budget_save_entry'),onPressed:busy?null:save,icon:const Icon(Icons.check),label:Text(busy?'သိမ်းနေတယ်…':'သိမ်းမယ်')),
      const SizedBox(height:24),
    ]));
  }
}

class BudgetPlanEditor extends StatefulWidget {
  final BudgetData data;
  final BudgetPlan? initial;
  final DateTime today;
  final Future<void> Function(int,BudgetPlan) onSave;
  const BudgetPlanEditor({super.key,required this.data,this.initial,required this.today,required this.onSave});
  @override
  State<BudgetPlanEditor> createState()=>_BudgetPlanEditorState();
}
class _BudgetPlanEditorState extends State<BudgetPlanEditor> {
  late final opening=TextEditingController(text:_editMoney(widget.data.opening));
  late final fixed=TextEditingController(text:_editMoney(widget.initial?.fixed??0));
  late final home=TextEditingController(text:_editMoney(widget.initial?.home??0));
  late final savings=TextEditingController(text:_editMoney(widget.initial?.savings??widget.data.planAt(widget.today)?.savings??0));
  DateTime get defaultStart {
    final previous=widget.data.planAt(widget.today);
    final end=previous==null?widget.today:parseBudgetDay(previous.end);
    return end.isAfter(widget.today)?end:widget.today;
  }
  late String start=widget.initial?.start??budgetDay(defaultStart);
  DateTime get defaultEnd {
    final next=DateTime.utc(defaultStart.year,defaultStart.month+1);
    return DateTime.utc(next.year,next.month,widget.data.plans.isEmpty?1:min(defaultStart.day,DateUtils.getDaysInMonth(next.year,next.month)));
  }
  late String end=widget.initial?.end??budgetDay(defaultEnd);
  bool busy=false;
  String? error;
  @override
  void dispose(){opening.dispose();fixed.dispose();home.dispose();savings.dispose();super.dispose();}
  Future<void> date(bool from)async{
    final chosen=await showDatePicker(context:context,initialDate:parseBudgetDay(from?start:end),firstDate:DateTime(2000),lastDate:DateTime(2100,12,31),helpText:from?'ဒီအစီအစဉ် စမယ့်ရက်':'နောက်ဝင်ငွေရမယ့်ရက်');
    if(chosen!=null&&mounted)setState((){if(from){start=budgetDay(DateTime.utc(chosen.year,chosen.month,chosen.day));}else{end=budgetDay(DateTime.utc(chosen.year,chosen.month,chosen.day));}});
  }
  Future<void> save()async{
    if(busy)return;
    FocusScope.of(context).unfocus();setState((){busy=true;error=null;});
    try{
      final value=BudgetPlan(id:widget.initial?.id??_id(),start:start,end:end,fixed:_amount(fixed.text,optional:true),home:_amount(home.text,optional:true),savings:_amount(savings.text,optional:true));
      final initial=_amount(opening.text,optional:true);
      BudgetData.fromJson(widget.data.copy(opening:initial,plans:[value,...widget.data.plans.where((p)=>p.id!=value.id)]).toJson(),today:widget.today);
      await widget.onSave(initial,value);
      if(mounted)Navigator.pop(context);
    }catch(e){if(mounted)setState(()=>error=e is FormatException?e.message:'သိမ်းမရသေးဘူး။ ပြန်စမ်းပေးပါ။');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Widget field(String key,String label,String hint,TextEditingController controller)=>Padding(padding:const EdgeInsets.symmetric(vertical:10),child:TextField(key:ValueKey(key),controller:controller,enabled:!busy,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,hintText:hint)));
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('ငွေစီမံမယ်')),body:ListView(padding:const EdgeInsets.all(20),children:[
    field('budget_opening','စာရင်းမစခင် ရှိငွေ (ဘတ်)','ဥပမာ 2000',opening),
    const Text('ဒီငွေဟာ အောက်က ဝင်ငွေမှတ်တမ်းတွေ မတိုင်မီ ရှိထားတဲ့ငွေပါ။ လက်ရှိစာရင်းထဲ ထည့်ပြီးသားလစာကို ဒီမှာ ထပ်မထည့်ဖို့ သတိထားပေးပါ။',style:TextStyle(fontSize:12,height:1.8)),
    const SizedBox(height:16),OutlinedButton(onPressed:busy?null:()=>date(true),child:Text('အစီအစဉ် စရက် · $start')),
    OutlinedButton(onPressed:busy?null:()=>date(false),child:Text('နောက်ဝင်ငွေရမယ့်ရက် · $end')),
    const Text('ဒီကာလအတွက် စုစုပေါင်း ဖယ်ထားချင်တဲ့ငွေကို ဖြည့်ပါ။ ပေးပြီးသမျှကို နုတ်ပြီး ပေးရန်ကျန်ငွေ ပြပေးမယ်။',style:TextStyle(height:1.8)),
    field('budget_fixed','ပုံမှန်ပေးစရာများအတွက် (ဘတ်)','ဥပမာ အခန်းခ / မီတာခ 3000',fixed),
    field('budget_home','အိမ်ကိုပို့ဖို့ (ဘတ်)','ဥပမာ 4000',home),
    field('budget_savings','စုငွေအဖြစ် မသုံးဘဲထားမယ့် စုစုပေါင်း (ဘတ်)','ဥပမာ 1000',savings),
    const Text('အရင်စုထားတာကိုပါ ဆက်ဖယ်ထားချင်ရင် ဒီစုစုပေါင်းထဲ ထည့်ထားပါ။',style:TextStyle(fontSize:12,height:1.8)),
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error,height:1.8)),
    const SizedBox(height:14),FilledButton(key:const ValueKey('budget_save_plan'),onPressed:busy?null:save,child:Text(busy?'သိမ်းနေတယ်…':'အစီအစဉ် သိမ်းမယ်')),
    const SizedBox(height:30),
  ]));
}

class BudgetRestorePage extends StatefulWidget {
  final BudgetStore store;
  final int currentCount;
  final Future<void> Function(BudgetData) onRestore;
  const BudgetRestorePage({super.key,required this.store,required this.currentCount,required this.onRestore});
  @override
  State<BudgetRestorePage> createState()=>_BudgetRestorePageState();
}
class _BudgetRestorePageState extends State<BudgetRestorePage> {
  final text=TextEditingController();
  BudgetData? preview;
  String? error;
  bool accepted=false,busy=false;
  @override
  void dispose(){text.dispose();super.dispose();}
  void check(){try{final value=widget.store.decode(text.text);setState((){preview=value;error=null;accepted=false;});}catch(e){setState((){preview=null;error=e is FormatException?e.message:'Backup ဖိုင်ကို ပြန်စစ်ပေးပါ။';});}}
  Future<void> restore()async{
    if(preview==null||!accepted||busy)return;
    setState(()=>busy=true);
    try{await widget.onRestore(preview!);if(mounted)Navigator.pop(context);}
    catch(e){if(mounted)setState(()=>error=e is FormatException?e.message:'သိမ်းမရသေးဘူး။ ပြန်စမ်းပေးပါ။');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Backup ပြန်ထည့်မယ်')),body:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('လက်ရှိ ကိုယ့်ငွေစာရင်းကို ဒီ backup နဲ့ အစားထိုးမှာပါ။ လက်ရှိစာရင်းကိုလည်း အရင် Backup သိမ်းထားနိုင်တယ်။ ငွေလဲမှတ်တမ်းနဲ့ နေ့စဉ်ဈေးကို မပြောင်းပါဘူး။',style:TextStyle(height:1.8)),
    if(kIsWeb)OutlinedButton.icon(onPressed:busy?null:()async{try{final raw=await pickBackup();if(raw!=null&&mounted){text.text=raw;check();}}catch(e){if(mounted)setState(()=>error=e is FormatException?e.message:'ဖိုင် ဖတ်မရသေးဘူး။');}},icon:const Icon(Icons.upload_file),label:const Text('Backup ဖိုင် ရွေးမယ်')),
    const SizedBox(height:14),TextField(key:const ValueKey('budget_backup_text'),controller:text,enabled:!busy,maxLines:6,decoration:InputDecoration(labelText: uiText(context, 'ဒါမှမဟုတ် Backup စာကို ဒီမှာ ကူးထည့်ပါ'),hintText:'{"kind":"bahtzay_budget", ...}'),onChanged:(_)=>setState((){preview=null;accepted=false;})),
    const SizedBox(height:14),OutlinedButton(key:const ValueKey('budget_preview_restore'),onPressed:busy?null:check,child:const Text('ဖိုင်ကို အရင်စစ်မယ်')),
    if(preview!=null)...[
      const SizedBox(height:16),Text('လက်ရှိမှတ်တမ်း ${widget.currentCount} ခု → Backup မှတ်တမ်း ${preview!.entries.length} ခု\nအစီအစဉ် ${preview!.plans.length} ခု · စာရင်းမစခင်ရှိငွေ ${money(preview!.opening)} ဘတ်',style:const TextStyle(height:1.8)),
      CheckboxListTile(key:const ValueKey('budget_confirm_restore'),contentPadding:EdgeInsets.zero,value:accepted,onChanged:busy?null:(v)=>setState(()=>accepted=v??false),title:const Text('လက်ရှိ ကိုယ့်ငွေစာရင်းကို အစားထိုးဖို့ အတည်ပြုတယ်')),
      FilledButton(key:const ValueKey('budget_restore'),onPressed:accepted&&!busy?restore:null,child:Text(busy?'သိမ်းနေတယ်…':'အတည်ပြုပြီး ပြန်ထည့်မယ်')),
    ],
    if(error!=null)Padding(padding:const EdgeInsets.only(top:14),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error,height:1.8))),
    const SizedBox(height:30),
  ]));
}
