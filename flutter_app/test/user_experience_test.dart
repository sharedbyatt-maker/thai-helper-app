import 'support/calculator_fixture.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/budget.dart';
import 'package:thai_helper/exchange/budget_page.dart';
import 'package:thai_helper/exchange/exchange_app.dart';
import 'package:thai_helper/exchange/models.dart';
import 'package:thai_helper/exchange/rates_repository.dart';
import 'package:thai_helper/exchange/storage.dart';
import 'package:thai_helper/exchange/trend_card.dart';

import 'support/app_update_fixture.dart';

ExchangeQuote quote() => ExchangeQuote(
  id: 'daily',
  label: 'နေ့စဉ်ဈေး',
  direction: ExchangeDirection.thbMmk,
  rateMicros: 125000000,
  sourceChecked: true,
  observedAt: DateTime.now().subtract(const Duration(minutes: 1)),
  validUntil: DateTime.now().add(const Duration(days: 1)),
);

RatesRepository repository({String notice = ''}) => RatesRepository(
  client: MockClient(
    (r) async => http.Response(
      jsonEncode(
        r.url.path.endsWith('/history')
            ? {'schema_version': 1, 'timezone': 'Asia/Bangkok', 'points': []}
            : {
                'schema_version': 2,
                'revision': 1,
                'published_at': DateTime.now().toIso8601String(),
                'notice': notice,
                'quotes': [quote().toJson()],
              },
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);

Future<void> start(WidgetTester t, {double width = 390}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    CurrencyApp(repository: repository(), updates: noNativeUpdates()),
  );
  await t.pumpAndSettle();
}

Future<void> tab(WidgetTester t, String name) async {
  await t.tap(find.widgetWithText(NavigationDestination, name));
  await t.pumpAndSettle();
}

Future<void> reveal(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Phone home exposes contextual help without duplicate freshness or announcements', (t) async {
    SharedPreferences.setMockInitialValues({});
    for (final font in [
      ('Noto Sans Myanmar', 'assets/fonts/NotoSansMyanmar.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(CurrencyApp(repository: repository(notice: 'Legacy announcement must stay off Home'), updates: noNativeUpdates()));
    await t.pumpAndSettle();
    final heading = find.byKey(const ValueKey('home_heading'));
    expect(heading, findsOneWidget);
    expect(find.descendant(of: heading, matching: find.byIcon(Icons.info_outline_rounded)), findsOneWidget);
    expect(find.textContaining('နောက်ဆုံးဈေး ·'), findsNothing);
    expect(find.textContaining('Latest rate ·'), findsNothing);
    expect(find.text('Legacy announcement must stay off Home'), findsNothing);
    expect(find.byKey(const ValueKey('home_announcement')), findsNothing);
    final direction = find.byKey(const ValueKey('direction_thb_mmk'));
    expect(t.getTopLeft(direction).dy, lessThan(210));
    final graph = find.byKey(const ValueKey('reference_rate_graph'));
    expect(t.getBottomRight(graph).dy, lessThan(750));
    expect(t.takeException(), isNull);
  });

  testWidgets('Home exposes rate sharing directly and Settings contains no Admin entry', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(CurrencyApp(repository: repository(), updates: noNativeUpdates()));
    await t.pumpAndSettle();
    final share = find.byKey(const ValueKey('home_share_rates'));
    await t.ensureVisible(share); await t.pumpAndSettle();
    await t.tap(share); await t.pumpAndSettle();
    expect(find.text('ပုံဖိုင်ယူမယ်'), findsNothing); // Widget tests use the native share label.
    expect(find.text('ပုံအဖြစ် မျှဝေမယ်'), findsOneWidget);
    await t.tap(find.text('ပိတ်မယ်')); await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('settings_button'))); await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings_admin')), findsNothing);
    expect(find.text('Admin'), findsNothing);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'First theme toggle works when the phone already uses dark mode',
    (t) async {
      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      await start(t);
      await t.tap(find.byKey(const ValueKey('settings_button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('settings_theme')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('settings_close')));
      await t.pumpAndSettle();
      expect(
        t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Changing tabs preserves the chart and budget page state', (
    t,
  ) async {
    await start(t);
    final chartState = t.state(find.byType(TrendCard));
    await tab(t, 'ငွေစာရင်း');
    final budgetState = t.state(find.byType(BudgetPage));
    await tab(t, 'ဘတ်ဈေး');
    expect(identical(chartState, t.state(find.byType(TrendCard))), true);
    await tab(t, 'ငွေစာရင်း');
    expect(identical(budgetState, t.state(find.byType(BudgetPage))), true);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Wide screens show quick calculation beside the chart and bound the budget width',
    (t) async {
      await start(t, width: 1366);
      final chart = t.getRect(find.byKey(const ValueKey('rate_trend_card')));
      final quick = t.getRect(find.byKey(const ValueKey('watch_amount')));
      expect(quick.left, greaterThan(chart.right));
      expect(quick.top, lessThan(chart.bottom));
      await tab(t, 'ငွေစာရင်း');
      expect(t.getSize(find.byType(ListView)).width, lessThanOrEqualTo(960));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Calculator errors identify the field and scroll it back into view',
    (t) async {
      await start(t);
      await tab(t, 'ငွေတွက်');
      final input = find.byKey(const ValueKey('amount'));
      await t.enterText(input, 'abc');
      final calculate = find.byKey(const ValueKey('calculate'));
      await reveal(t, calculate);
      await t.tap(calculate);
      await t.pumpAndSettle();
      expect(t.widget<TextField>(input).decoration!.errorText, isNotNull);
      expect(t.getRect(input).top, greaterThanOrEqualTo(0));
      await t.enterText(input, '1000');
      await openRateEditor(t);
      final rate = find.byKey(const ValueKey('rate_0'));
      await reveal(t, rate);
      await t.enterText(rate, 'wrong');
      await reveal(t, calculate);
      await t.tap(calculate);
      await t.pumpAndSettle();
      expect(t.widget<TextField>(rate).decoration!.errorText, isNotNull);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Back from a dirty budget entry preserves the draft until explicitly discarded',
    (t) async {
      await start(t);
      await tab(t, 'ငွေစာရင်း');
      await t.tap(find.byKey(const ValueKey('budget_add_expense')));
      await t.pumpAndSettle();
      final field = find.byKey(const ValueKey('budget_amount'));
      await t.enterText(field, '50');
      await t.pump();
      await t.tap(find.byType(BackButton).first);
      await t.pumpAndSettle();
      expect(find.text('မသိမ်းရသေးတာတွေ ရှိတယ်'), findsOneWidget);
      await t.tap(find.text('ဆက်ဖြည့်မယ်'));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(field).controller!.text, '50');
      final save = find.byKey(const ValueKey('budget_save_entry'));
      await reveal(t, save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('budget_amount')), findsNothing);
      expect((await BudgetStore().load()).entries.single.amount, 5000);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('History search can be reset without modifying saved records', (
    t,
  ) async {
    final q = quote();
    await RecordStore().save([
      PersonalRecord(
        id: 'one',
        name: 'Home',
        note: 'salary',
        quote: q,
        budgetMinor: 100000,
        receivedMinor: q.payout(100000),
        savedAt: DateTime.now(),
      ),
    ]);
    await start(t);
    await tab(t, 'မှတ်တမ်း');
    final search = find.byKey(const ValueKey('history_search'));
    await reveal(t, search);
    await t.enterText(search, 'does not exist');
    await t.pumpAndSettle();
    final reset = find.byKey(const ValueKey('history_reset_filters'));
    await reveal(t, reset);
    await t.tap(reset);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('personal_record_one')), findsOneWidget);
    expect((await RecordStore().load()).single.note, 'salary');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Cached quotes are never labelled freshly verified', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrendCard(
              quotes: [quote()],
              history: null,
              loading: false,
              unavailable: true,
              cached: true,
              onCalculate: (_) {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('သိမ်းထားတဲ့ဈေး'), findsOneWidget);
    expect(find.text('စစ်ထားပြီး'), findsNothing);
    expect(t.takeException(), isNull);
  });
}

