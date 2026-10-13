#!/usr/bin/env python3
"""Semi-auto rate update (v1).

Fetches the live THB->MMK mid-market rate from a free API, then applies
each channel's typical margin (margin_mmk in rates.json) to estimate the
channel rate.

Channel rates are ESTIMATES, not quotes: margins drift. The script always
leaves verified=false so the app shows the honest state. A human should
spot-check TrueMoney/WU counters daily and flip verified=true.

Run daily (cron):  python3 update_rates.py
"""
import json
import urllib.request
from datetime import datetime, timedelta, timezone

ER_API = "https://open.er-api.com/v6/latest/THB"
RATES_FILE = "rates.json"
BKK = timezone(timedelta(hours=7))


def fetch_mid_market():
    with urllib.request.urlopen(ER_API, timeout=20) as r:
        d = json.load(r)
    if d.get("result") != "success":
        raise RuntimeError(f"API failed: {d}")
    return float(d["rates"]["MMK"])


def main():
    mid = fetch_mid_market()
    with open(RATES_FILE, encoding="utf-8") as f:
        data = json.load(f)
    for ch in data["channels"]:
        margin = float(ch.get("margin_mmk", 1.0))
        ch["rate_thb_mmk"] = round(mid - margin, 2)
        ch["verified"] = False  # estimates until human confirms
    data["mid_market_rate"] = round(mid, 2)
    data["mid_market_source"] = "open.er-api.com (auto)"
    data["updated_at"] = datetime.now(BKK).isoformat(timespec="seconds")
    with open(RATES_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"mid-market {mid:.2f} -> updated {len(data['channels'])} channels "
          f"(estimates, verified=false)")


if __name__ == "__main__":
    main()
