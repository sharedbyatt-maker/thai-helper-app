# Thai Helper App — MVP Plan (v1)

**Target user:** ထိုင်းရောက် မြန်မာရွှေ့ပြောင်းလုပ်သား (~၄-၅ သန်း)
**Platform:** Flutter (Android + iOS, codebase တစ်ခု) — `flutter_tts` (on-device TTS, အခမဲ့/offline)
**Monetization v1:** မပါ (user စု) → v2: ငွေလွှဲ referral + translator subscription

## Modules (v1 = ၂ ခု)

### A. ထိုင်းစကားစာအုပ် (offline phrasebook)
- Category ၁၀ ခု, စကားစု ~၁၅၀ (data/phrases_v1.json)
- တစ်ခုချင်းစီမှာ: မြန်မာလို + ထိုင်းလို + မြန်မာအသံထွက် (စဝတ်ဒီ) + 🔊 အသံထွက်ခလုတ် (on-device TTS)
- Search (မြန်မာလို ရိုက်ရှာ), Favorites (ကြိုက်နှစ်သက်ရာ သိမ်း)
- **သတိ:** ထိုင်းစာသားအားလုံး native speaker စစ်ဆေးရန် လိုအပ်သည် (လက်ရှိမူကြမ်းသာ)

### B. ငွေလွှဲနှုန်း နှိုင်းယှဉ်ချက် (remittance rates)
- Channel တွေ: TrueMoney, Western Union, MoneyGram, KBZPay/Wave (ရရင်), hundi ရည်ညွှန်း
- ပြသရန်: ပမာဏ (ဘတ်) → လက်ခံရမယ့် ကျပ် + fee + ရောက်ချိန် ခန့်မှန်း
- **Backend လိုအပ်သည်** (Flask/FastAPI): rate scraping/manual update → API → app
- v1 မှာ manual update (နေ့တိုင်း/အပတ်တိုင်း) လည်း ရသည်

## Screens (v1)
1. Home — module ၂ ခု + နေ့စဉ်စကားစု ၁ ခု (retention)
2. Phrasebook — category list → phrase list → phrase detail (အသံခလုတ် ကြီးကြီး)
3. Search / Favorites
4. Rates — ပမာဏထည့် → channel နှိုင်းယှဉ်ဇယား
5. Settings — TTS အသံစစ်ဆေးရန် (voice pack download လမ်းညွှန်)

## Tech decisions (locked)
- Flutter + flutter_tts (on-device, $0)
- Phrases: local JSON, offline-first
- Rates: Flask backend (မင်းကျွမ်းပြီးသား) + simple REST
- Distribution v1: APK direct via Facebook (Play Console restricted ဖြစ်နေဆဲ)
- iOS နောင်: Apple Developer $99/နှစ် + Mac/CI build

## Milestones
- [ ] M1: phrases_v1.json ပြီးစီး + ထိုင်းလူမျိုး စစ်ဆေးချက်
- [ ] M2: Flutter scaffold + phrasebook UI + TTS
- [ ] M3: Rates backend + UI
- [ ] M4: Beta (လူ ၅၀-၁၀၀) → feedback → v1.1
- [ ] Phase 2: live translator (user/revenue ရမှ)

## Phase 2 (ရွှေ့ထား)
- Live voice translator: STT→Translate→TTS, daily free quota + ~49 THB/mo subscription
- Camera Thai→Burmese OCR (စာရွက်စာတမ်း/ဆိုင်းဘုတ်)
- Cloud TTS pre-generated audio (စကားစုစာရင်း တည်ငြိမ်မှ)
