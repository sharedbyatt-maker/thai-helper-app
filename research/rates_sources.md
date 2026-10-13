# Module B — ငွေလွှဲနှုန်း ဒေတာရင်းမြစ် သုတေသန (M3 အတွက် ကြိုတင်ပြင်ဆင်ချက်)

စစ်ဆေးသည့်နေ့: 2026-10-13. Module B (rates comparison) အတွက် channel တစ်ခုချင်းစီရဲ့ fee structure ကို အတိအကျ တွေ့ရှိချက်များ။

## Fee structures (verified 2026-10-13)

| Channel | Fee | မှတ်ချက် |
|---|---|---|
| TrueMoney Transfer | Tiered: 100–5,000฿→50฿; 5,001–10,000฿→100฿; 10,001–15,000฿→150฿; 15,001–20,000฿→200฿; 20,001–25,000฿→250฿; 25,001–30,000฿→300฿ | retailnews.asia article (crawl 2026-10-13). ပျမ်းမျှလွှဲငွေ 6,650฿ → fee 100฿ |
| DeeMoney | **133.75฿ flat** (125฿ + 7% VAT) | moneymgmnt.com (updated ~2026-03). ⚠️ 2023 Khaosod article မှာ Myanmar promo 49฿ flat လို့ဆို — fee ပြောင်းသွားပြီ ဖြစ်နိုင်, app မတိုင်ခင် ပြန်စစ်ရန် |
| Krungthai Bank (→Myanmar) | **150฿ flat / transaction** | krungthai.com/en/personal (တရားဝင်စာမျက်နှာ) |
| Western Union | ~160฿ flat | အရင်ဆွေးနွေးမှုမှ (ဒီ run မှာ ပြန်မစစ်ရ) — M3 မှာ verify |
| Hundi (informal) | ~5% | အရင်ဆွေးနွေးမှုမှ; ဈေးနှုန်းက broker အလိုက် ကွာနိုင် — ရည်ညွှန်းအနေနဲ့သာ ပြရန် |

## နမူနာ နှိုင်းယှဉ်ချက် (6,650฿ ပျမ်းမျှလွှဲ, rate ခန့်မှန်း 62.7 MMK/฿ — exchangerate.guru, 2026-10-12)

- TrueMoney: 6,650 − 100 = 6,550฿ → ~410,685 ကျပ်
- DeeMoney: 6,650 − 133.75 = 6,516.25฿ → ~408,569 ကျပ်
- Krungthai: 6,650 − 150 = 6,500฿ → ~407,550 ကျပ်
- WU: 6,650 − 160 = 6,490฿ → ~406,923 ကျပ်
- Hundi (5%): 6,650 − 332.5 = 6,317.5฿ → ~396,107 ကျပ်

(ဒါက fee သာ နှိုင်းတာ — တကယ့် channel တိုင်းက သူ့ exchange rate သူ့ဟာနဲ့မို့, rate ကွာခြားမှုက fee ထက် ပိုကြီးနိုင်တယ်။ App မှာ "fee + effective rate" နှစ်ခုလုံး ပြရမယ်။)

## Rate data ဘယ်က ယူမလဲ (M3 အတွက်)

1. **v1 (အကြံပြု): manual update** — admin endpoint တစ်ခုကနေ နေ့တိုင်း channel တိုင်းရဲ့ rate ကို ကိုယ်တိုင် ထည့်။ အလုပ်အများဆုံး ယုံကြည်ရဆုံး။ Channel ၅-၆ ခုကို နေ့တိုင်း စစ်တာ မိနစ် ၁၀-၁၅ ပဲ ကြာမယ်။
2. **Display baseline:** exchangerate.guru လို public converter စာမျက်နှာက mid-market-ish rate ကို scrape လုပ်ပြီး "ဈေးကွက်နှုန်း ရည်ညွှန်း" အနေနဲ့ ပြနိုင် (HTML structure ပြောင်းနိုင်လို့ fragile — fallback ထားရန်)။
3. **Channel ကိုယ်ပိုင် rate:** TrueMoney/DeeMoney/Krungthai တို့က rate ကို app/website calculator ထဲမှာပဲ ပြတာ — public API မရှိ။ v1 မှာ scrape မလုပ်နဲ့, manual ပဲ။
4. **Wise API** (လိုအပ်ရင် နောက်): public calculator endpoint ရှိတတ်တယ် — M3 အချိန်ကျ verify လုပ်ရန်။

## သတိထားရန်
- ငွေလွှဲလုပ်ငန်း **ကိုယ်တိုင် မလုပ်ရ** — rate ပြတာ + referral link ပဲ (license ငရဲ ရှောင်ရန်)။ ဒါ MVP_PLAN.md မှာလည်း ပါပြီးသား။
- DeeMoney fee 49฿→133.75฿ ပြောင်းသွားပုံက fee တွေ ခဏခဏ ပြောင်းတတ်တာကို ပြတယ် — fee table ကို app ထဲမှာ hardcode မလုပ်ဘဲ backend config အနေနဲ့ ထား။
- 25% bank-transfer rule (စစ်ကောင်စီ စည်းကမ်း) ကို rate screen မှာ disclaimer အနေနဲ့ ထည့်စဉ်းစားရန် — user တွေ စိုးရိမ်နေတဲ့ pain point.

## Sources (စစ်ဆေးသည့်နေ့ 2026-10-13)
- https://retailnews.asia/truemoney-transfer-is-thailands-first-affordable-remittance-solution-for-migrant-workers (TrueMoney tiers)
- https://www.moneymgmnt.com/managing-money/transferring-money-out-of-thailand/ (DeeMoney 133.75฿)
- https://krungthai.com/en/personal/cash-management/payment-transfer/463 (Krungthai 150฿)
- https://www.khaosodenglish.com/sponsored/2023/11/07/deemoney-increases-cross-border-payments-to-myanmar-market/ (DeeMoney 49฿ promo, 2023 — outdated)
- https://exchangerate.guru/thb/mmk/1150/ (62.7 MMK/฿, 2026-10-12)
