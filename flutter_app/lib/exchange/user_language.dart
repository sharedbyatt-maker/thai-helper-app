import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart' show BuildContext, InheritedWidget, Key, Widget, ValueChanged;

/// User-facing language. Administrative records and money data stay unchanged.
enum UserLanguage { myanmar, english }

class UserLanguageScope extends InheritedWidget {
  final UserLanguage language;
  final ValueChanged<UserLanguage> onChanged;

  const UserLanguageScope({
    super.key,
    required this.language,
    required this.onChanged,
    required super.child,
  });

  static UserLanguageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UserLanguageScope>();

  @override
  bool updateShouldNotify(UserLanguageScope oldWidget) =>
      language != oldWidget.language || onChanged != oldWidget.onChanged;
}

String uiTranslate(String source, UserLanguage language) {
  if (language == UserLanguage.myanmar || source.isEmpty) return source;
  if (_en.containsKey(source)) return _en[source]!;
  var result = source;
  // Translate longer UI phrases before shared shorter units so dynamic totals
  // and interpolated dates remain readable. Preserve unknown/user-entered data.
  for (final entry in _ordered) {
    if (result.contains(entry.key)) result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

final _ordered = _en.entries.toList()
  ..sort((a, b) => b.key.length.compareTo(a.key.length));

String uiText(BuildContext context, String source) =>
    uiTranslate(source, UserLanguageScope.maybeOf(context)?.language ?? UserLanguage.myanmar);

/// Retains the Flutter Text API and const call sites while translating
/// visible copy when English is selected. No currency data is modified.
class Text extends material.Text {
  const Text(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    final lang = UserLanguageScope.maybeOf(context)?.language ?? UserLanguage.myanmar;
    if (lang == UserLanguage.myanmar || data == null) return super.build(context);
    return material.Text(
      uiTranslate(data!, lang),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : uiTranslate(semanticsLabel!, lang),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

class LanguageMenu extends material.StatelessWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = UserLanguageScope.maybeOf(context);
    if (scope == null) return const material.SizedBox.shrink();
    return material.PopupMenuButton<UserLanguage>(
      key: const Key('language_menu'),
      tooltip: scope.language == UserLanguage.english ? 'Language' : 'ဘာသာစကား',
      icon: const material.Icon(material.Icons.language_rounded),
      onSelected: scope.onChanged,
      itemBuilder: (_) => [
        material.CheckedPopupMenuItem<UserLanguage>(
          value: UserLanguage.myanmar,
          checked: scope.language == UserLanguage.myanmar,
          child: const material.Text('မြန်မာ'),
        ),
        material.CheckedPopupMenuItem<UserLanguage>(
          value: UserLanguage.english,
          checked: scope.language == UserLanguage.english,
          child: const material.Text('English'),
        ),
      ],
    );
  }
}

const _en = <String, String>{
  // Main navigation and basic directions.
  'ဘတ်ဈေး':'BahtZay',
  'နေ့စဉ်ဈေး':'Daily rates',
  'ငွေတွက်':'Calculator',
  'ငွေစာရင်း':'My money',
  'မှတ်တမ်း':'History',
  'ဘတ်ပေး → ကျပ်ယူ':'Pay THB → Receive MMK',
  'ကျပ်ပေး → ဘတ်ယူ':'Pay MMK → Receive THB',
  'ဘတ်ပေး':'Pay THB',
  'ကျပ်ပေး':'Pay MMK',
  'ကျပ်ယူ':'Receive MMK',
  'ဘတ်ယူ':'Receive THB',
  'ဘတ်':'THB',
  'ကျပ်':'MMK',
  'ထိုင်းအချိန်':'Thailand time',
  'ထိုင်း':'Thailand',
  'ဒီနေ့':'Today',
  'မနေ့က':'Yesterday',
  'မနက်ဖြန်':'Tomorrow',
  'ကြည့်မယ်':'View',
  'တင်ထားပါတယ်':'published',
  'ခု':'',
  'ရက်':'days',
  // Rates, navigation, charts and help.
  'ဒီနေ့ ဘတ်–ကျပ်ဈေး':'Today’s THB / MMK rates',
  'ဘတ်ပေးမလား၊ ကျပ်ပေးမလား ရွေးပြီး ဈေးကြည့်လိုက်ပါ။':'Choose a direction to view its latest rate.',
  'နောက်ဆုံးဈေး':'Latest rate',
  'စစ်ထားပြီး':'Recently checked',
  'ပြန်စစ်ဖို့လိုနေပြီ':'Needs rechecking',
  'ပြန်မစစ်ရသေး':'Not recently checked',
  'မတင်ရသေးပါ':'Not published yet',
  'မတင်ရသေးဘူး':'Not published yet',
  'ဒီဘက်ဈေး မတင်ရသေးဘူး':'No rate has been published for this direction.',
  'ဒီဘက်ဈေး မတင်ရသေးပါ':'No rate has been published for this direction.',
  'ဒီဘက်ဈေး တင်လာရင် တွက်ပြပေးမယ်။':'A result will appear when a rate is published.',
  'ဈေးအသစ် မတင်ရသေးပါ။ နောက်ဆုံးတင်ထားတဲ့ဈေးနဲ့ တွက်ကြည့်နိုင်ပါတယ်။':'No new rate yet. You can calculate with the last published rate.',
  'ဈေးအသစ် ယူမရသေးဘူး။ ကိုယ်ရထားတဲ့ဈေးနဲ့ တွက်လို့ရပါတယ်။':'Could not get a new rate. You can still use your saved rate.',
  'လိုင်းမရသေးလို့ သိမ်းထားတဲ့ဈေးကို ပြထားပါတယ်':'Offline: showing the last cached rates.',
  'ဈေးအသစ် မရသေးပါဘူး':'No new rate available.',
  'နောက်ဆုံးချိတ်ဆက်ချိန်':'Last connected',
  'နောက်ဆုံးစစ်ချိန်':'Last checked',
  'ဈေးစစ်ချိန်':'Checked at',
  'ဈေးတင်ချိန်':'Published at',
  'အဟောင်းဈေး · ပြန်မစစ်ရသေးပါ':'Older rate · not recently checked',
  'ဈေးအသစ်တင်ရင် ဒီနေရာမှာ ပြပေးမယ်။':'New published rates will appear here.',
  'အရင်တင်ထားတဲ့ဈေးတွေ ယူနေပါတယ်':'Loading rate history…',
  'ဈေးမှတ်တမ်း မရှိသေးဘူး':'No rate history yet',
  'ဒီရက်တွေအတွက် ဈေးမှတ်တမ်း မရှိသေးဘူး။':'No rate history for these dates.',
  'ဈေးဘယ်လို ပြောင်းသွားလဲ?':'How have rates changed?',
  'ကြည့်ချင်တဲ့ဈေး':'Select a rate',
  'အနိမ့်':'Lowest',
  'အမြင့်':'Highest',
  'ဈေးတင်ထားတဲ့ရက်':'Days with published rates',
  'ဈေးတင်ထားတာ':'Published quotes',
  'မှတ်တမ်းကာလ':'Selected period',
  'အမှတ်လေးကို ထိပြီး ဈေးနဲ့အချိန် ကြည့်လို့ရပါတယ်':'Tap a chart point to see the rate and time',
  'အမှတ်လေးကို ထိကြည့်ပါ။':'Tap the point to inspect it.',
  'ဈေးတစ်ကြိမ်ပဲ တင်ထားသေးတယ်။':'Only one rate has been published.',
  'အရင်ဈေးတွေ ယူမရသေးဘူး။ နောက်ဆုံးရထားတဲ့ဈေးကိုတော့ ပြထားပါတယ်။':'Could not load earlier rates. The latest available rate is shown.',
  'ရယူနေပါတယ်…':'Loading…',
  'သိမ်းထားတဲ့မှတ်တမ်း':'Cached history',
  '၁ သိန်းရဖို့ ပေးရမယ့်ဘတ်':'THB needed for 100,000 MMK',
  '၁ သိန်းပေးရင် ရမယ့်ဘတ်':'THB received for 100,000 MMK',
  'ကျပ် ၁ သိန်းအတွက် ဘတ်':'THB per 100,000 MMK',
  'ကျပ် ၁ သိန်း':'100,000 MMK',
  '၁ ဘတ်အတွက် ကျပ်':'MMK per 1 THB',
  'ဒီနှုန်းနဲ့ တွက်မယ်':'Calculate with this rate',
  'နောက်ဆုံးဈေးနဲ့ တွက်မယ်':'Calculate with the latest rate',
  'ကိုယ်ရထားတဲ့ဈေးနဲ့ တွက်မယ်':'Calculate using my rate',
  'ငွေမလဲခင် နောက်ဆုံးဈေးကို ပြန်မေးပေးပါ။':'Confirm the latest rate with your exchange provider before exchanging.',
  'ဈေးအသစ် ယူမယ်':'Refresh rates',
  'အလင်း / အမှောင်':'Light / dark mode',
  'အသုံးပြုနည်း':'How to use',
  'နားလည်ပါပြီ':'Got it',
  'နားလည်ပြီ':'Got it',
  'App version / Update စစ်မယ်':'Check app version / updates',
  // Calculator.
  'ငွေလဲတွက်မယ်':'Currency calculator',
  'ပေးမယ့်ငွေနဲ့ ဈေးထည့်လိုက်ပါ။ ရမယ့်ငွေကို တွက်ပေးမယ်။':'Enter the amount and the rate to calculate the result.',
  'ဘယ်လောက် ရချင်လဲ?':'How much do you want to receive?',
  'ဘယ်လောက် ပေးမလဲ?':'How much will you pay?',
  'ရချင်တဲ့ပမာဏ':'Desired amount',
  'ပေးမယ့်စုစုပေါင်းငွေ':'Amount to pay',
  'ပေးမယ့်ငွေ':'Amount to pay',
  'ကိုယ့်ငွေနဲ့ဆို':'With your money',
  'ဒီနေ့ရမယ့်ငွေ':'Amount you’ll receive today',
  'နောက်ဆုံးစစ်ထားတဲ့ဈေးနဲ့ဆို':'Using the last checked rate',
  'ပေးမယ့်ငွေနဲ့ ပြန်တွက်မယ်':'Calculate from amount paid',
  '✓ တွက်ပြီးပြီ':'✓ Calculated',
  'လိုအပ်မယ့်ငွေ တွက်မယ်':'Calculate required amount',
  'တွက်ပြီး နှိုင်းမယ်':'Calculate and compare',
  'ရမယ့်ငွေ တွက်မယ်':'Calculate received amount',
  'ဈေးနှိုင်းမယ် / ရချင်တဲ့ငွေနဲ့ တွက်မယ်':'Compare rates / calculate target amount',
  'နှိုင်းဖို့ ဈေးတစ်ခု ထပ်ထည့်မယ်':'Add a rate to compare',
  'ပေးမယ့်ငွေနဲ့ တွက်မယ်':'Calculate from payment',
  'ရချင်တဲ့ငွေကနေ ပြန်တွက်မယ်':'Calculate required payment',
  'ရထားတဲ့ ငွေလဲနှုန်း':'Saved exchange rate',
  'နှိုင်းမယ့်ဈေး':'Comparison rate',
  'ဒီဈေးကို ဖယ်မယ်':'Remove this rate',
  'ဈေးရေးပုံ':'Rate format',
  'ဒီဈေးကို နာမည်ပေးထားချင်လား?':'Give this rate a name?',
  'မှတ်ထားမယ့်နာမည်':'Name for this rate',
  'ဥပမာ အသိတစ်ယောက်ပေးတဲ့ဈေး':'e.g. rate from a friend',
  'ဥပမာ':'e.g.',
  'အနည်းဆုံးနဲ့ အများဆုံး ကွာခြားချက်':'Difference between lowest and highest',
  'အများဆုံးနဲ့ အနည်းဆုံး ကွာခြားချက်':'Difference between highest and lowest',
  'ရမယ့်ငွေ':'Amount received',
  'ရငွေ':'Received',
  'လိုအပ်မယ့်ငွေ':'Required amount',
  'အနည်းဆုံးပါ':'the lowest',
  'အများဆုံးပါ':'the highest',
  'သီးသန့်နုတ်ငွေ':'Deduction',
  'မှတ်တမ်းသိမ်း':'Save record',
  'မျှဝေမယ်':'Share',
  'တွက်ထားတာကို သိမ်းမယ်':'Save calculation',
  'အခုတွက်ထားတာကို သိမ်းပေးမယ်။ တကယ်ငွေလဲပြီးရင် မှတ်တမ်းထဲမှာ အမှန်ခြစ်ထားလို့ရပါတယ်။':'This calculation will be saved. Mark it completed after the actual exchange.',
  'မှတ်ချက် (ရေးချင်မှ)':'Note (optional)',
  'မသိမ်းတော့':'Cancel',
  'သိမ်းမယ်':'Save',
  'သိမ်းပြီးပါပြီ':'Saved successfully',
  'ပြန်တွက်မယ်':'Recalculate',
  'နှိုင်းဖို့ အရင်ရက်ဈေး မရှိသေးဘူး။':'No previous rate available for comparison.',
  'ပမာဏကို ဒီဖုန်းထဲမှာပဲ မှတ်ထားပေးမယ်။':'This amount is saved only on this device.',
  // Exchange history.
  'ကိုယ့်ငွေလဲမှတ်တမ်း':'My exchange history',
  'တွက်ထားတာနဲ့ လဲပြီးတာကို ဒီမှာ မှတ်ထားလို့ရတယ်။ ဒီဖုန်းရဲ့ browser ထဲမှာပဲ သိမ်းထားတာပါ။':'Keep calculations and completed exchanges here, stored only in this browser.',
  'မှတ်တမ်းတွေ ဖတ်မရသေးဘူး။ သိမ်းထားတဲ့စာရင်းကို မပြောင်းထားပါဘူး။':'Cannot read your records; your stored data was not changed.',
  'ပြန်ဖတ်မယ်':'Reload',
  'ဒီလ ငွေလဲပြီးသမျှ':'Exchanges completed this month',
  'ကြိမ်':'times',
  'အားလုံး':'All',
  'မှတ်တမ်း မရှိသေးဘူး':'No records yet',
  'ဒီဘက်အတွက် မှတ်တမ်း မရှိသေးဘူး':'No records for this direction',
  'မှတ်တမ်းဖိုင် ပြန်သွင်းမယ်':'Import history backup',
  'မှတ်တမ်းဖိုင် သိမ်းမယ်':'Export history backup',
  'အားလုံးရှင်းမယ်':'Clear all',
  'ငွေတွက်မယ်':'Open calculator',
  'စုစုပေါင်းပေးငွေ':'Total paid',
  'စုစုပေါင်းရငွေ':'Total received',
  'ငွေလဲပြီးပြီ':'Exchange completed',
  'တွက်ထားတာပဲ ရှိသေးတယ်':'Calculated only',
  'ကိုယ်တိုင် မှတ်ထားတာပါ':'Saved manually',
  'လဲပြီးတဲ့ရက်':'Date exchanged',
  'ဒီဈေးနဲ့ ပြန်တွက်မယ်':'Recalculate with this rate',
  'ဖျက်မယ်':'Delete',
  'မဖျက်တော့':'Cancel',
  'တကယ်ဖျက်မလား?':'Confirm deletion?',
  'မှတ်တမ်းကို ဖျက်မလား?':'Delete this record?',
  'ဖိုင်ထုတ်သိမ်းပြီးပြီလား?':'Have you exported a backup?',
  'ပေါင်းထည့်မယ်':'Import and merge',
  'မသွင်းတော့':'Cancel',
  'တကယ်ငွေလဲပြီးတဲ့ရက်':'Actual exchange date',
  // Budget.
  'ကိုယ့်ငွေစာရင်း':'My money',
  'ကိုယ့်ငွေကို စီမံမယ်':'Manage your money',
  'စာရင်းပြန်ဖတ်မယ်':'Refresh records',
  'Backup / အကူအညီ':'Backup / Help',
  'ဝင်ငွေ':'Income',
  'သုံးငွေ':'Expenses',
  'အိမ်ပို့ပြီးငွေ':'Money sent home',
  'လစာ':'Salary',
  'နေ့စား':'Daily wages',
  'စားသောက်':'Food',
  'အခန်းခ / အိမ်စရိတ်':'Rent / household',
  'သွားလာရေး':'Transport',
  'ကျောင်း / သင်တန်း':'School / training',
  'ဖုန်း / မီတာခ':'Phone / utilities',
  'ကျန်းမာရေး':'Health',
  'အခြား':'Other',
  'မုန့်ဖိုး / ထောက်ပံ့ငွေ':'Allowance',
  'Tip / အပိုရငွေ':'Tips / other income',
  'နေ့လယ်စာ':'Lunch',
  'ဖယ်ထားငွေ':'Reserved money',
  'ဖယ်ထားပြီး သုံးလို့ရမယ့်ငွေ':'Available after reserves',
  'လက်ကျန်':'Balance',
  'ယနေ့ လက်ကျန်':'Current balance',
  'အိမ်ပို့ရန်':'To send home',
  'စုငွေ':'Savings',
  'အိမ်ပို့ငွေ':'Remittance',
  'စာရင်းမစခင်ရှိငွေ':'Starting balance',
  'ဒီလ':'This month',
  'နေ့':'days',
  'သုံးငွေမှတ်မယ်':'Add expense',
  'ဝင်ငွေမှတ်မယ်':'Add income',
  'အိမ်ပို့ပြီးတာ မှတ်မယ်':'Record remittance',
  'အစီအစဉ်':'Plan',
  'အစီအစဉ် သိမ်းမယ်':'Save plan',
  'အစီအစဉ် အသစ်':'New plan',
  'အလုပ်ရမယ့်ရက်':'Next payday',
  'ရပြီးသား':'Received',
  'ပြင်မယ်':'Edit',
  'လက်ရှိ':'Current',
  'လက်ရှိမှတ်တမ်း':'Current entries',
  'အရင်':'Previous',
  'လက်ရှိ ကိုယ့်ငွေစာရင်းကို အစားထိုးဖို့ အတည်ပြုတယ်':'I confirm replacing my existing budget data',
  'အတည်ပြုပြီး ပြန်ထည့်မယ်':'Confirm and restore',
  'ဖိုင်ကို အရင်စစ်မယ်':'Validate backup first',
  'ဖိုင် ဖတ်မရသေးဘူး။':'Cannot read the selected file.',
  'Backup ဖိုင် ရွေးမယ်':'Choose backup file',
  'Backup ဖိုင်ယူမယ်':'Download backup',
  'Backup ပြန်ထည့်မယ်':'Restore backup',
  'ငွေစာရင်း Backup သိမ်းမယ်':'Back up money records',
  'မှတ်တမ်းအားလုံး Backup':'Full backup',
  'မှတ်တမ်းအားလုံး သိမ်းမယ်':'Back up all records',
  'Backup စာ ကူးမယ်':'Copy backup text',
  'Backup ဖိုင်ကို အရင်စစ်မယ်':'Check backup first',
  'Backup စာကို ကူးထည့်ပါ':'Paste backup text',
  'အတည်ပြုတယ်':'I confirm',
  'ပိတ်မယ်':'Close',
  'ပြန်စမ်းပေးပါ။':'Please try again.',
  'သိမ်းနေတယ်…':'Saving…',
  'သိမ်းနေပါတယ်။':'Saving…',
  'မရသေးဘူး':'Not available yet',
  // Tools, alerts, mobile.
  'ဈေးအသိပေးမယ်':'Set a price alert',
  'ဈေးနှုန်း မျှဝေမယ်':'Share rates',
  'လဲဖို့ရက် မှတ်ထားမယ်':'Plan an exchange date',
  'ရက်မှတ်ထားတာ ဖယ်မယ်':'Remove planned date',
  'စဉ်းစားထားတဲ့ရက်':'Planned date',
  'ဖုန်းမျက်နှာပြင်ပေါ် ထည့်ထားမယ်':'Add to Home Screen',
  'ဈေးနဲ့ ကြေညာချက် အသိပေးမယ်':'Rate and announcement alerts',
  'Telegram နဲ့ စောင့်မယ်':'Watch on Telegram',
  'ဈေးအသစ်တင်တိုင်း အသိပေးမယ်':'Notify me of new rates',
  'Telegram မှာ ဆက်ဖွင့်မယ်':'Continue in Telegram',
  'Telegram ဖွင့်မရသေးဘူး။ ပြန်စမ်းပေးပါ။':'Could not open Telegram. Try again.',
  'ဖုန်းမှာ အသိပေးမယ်':'Phone notifications',
  'ဖုန်း noti ဖွင့်မယ်':'Enable phone notifications',
  'Noti ပိတ်မယ်':'Disable notifications',
  'Noti စမ်းကြည့်မယ်':'Test notification',
  'ဖုန်း noti မဖွင့်ရသေးဘူး':'Phone notifications are off',
  '✓ ဖုန်း noti ဖွင့်ထားတယ်':'✓ Phone notifications enabled',
  'ချိတ်ဆက်နေတယ်…':'Connecting…',
  'ကိုယ်ရေးအချက်အလက် အသေးစိတ်':'Privacy details',
  'ပုံအဖြစ် မျှဝေမယ်':'Share image',
  'ပုံပြင်ဆင်နေပါတယ်':'Preparing image…',
  'ဖုန်းထဲ သိမ်းမရသေးဘူး။ ပြန်စမ်းပေးပါ။':'Could not save on this device. Please retry.',
  'Update စစ်မရသေးဘူး။':'Could not check for updates.',
  'Version အသစ်ရပြီ':'New version available',
  'အသစ်':'New',
  'နောက်မှလုပ်မယ်':'Later',
  'ပြန်စစ်မယ်':'Check again',
  'APK အသစ်ယူမယ်':'Download new APK',
  'Play Store မှာ Update လုပ်မယ်':'Update in Play Store',
};
