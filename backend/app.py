"""Remittance rate comparison API (v1).

Serves channel data for THB -> MMK transfers. This is an INFORMATION
service only: it compares publicly listed fees/rates. It does NOT move
money and is NOT a money transmitter.

v1 data model: rates are updated MANUALLY in rates.json (daily).
Each channel carries updated_at + verified flag so the app can show
data freshness honestly.
"""
import json
import os
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

BASE = os.path.dirname(os.path.abspath(__file__))
RATES_FILE = os.path.join(BASE, "rates.json")


def load_rates():
    with open(RATES_FILE, encoding="utf-8") as f:
        return json.load(f)


def fee_for(channel, amount):
    """Return the fee in THB for a given amount, or None if not covered."""
    if channel.get("flat_fee") is not None:
        return float(channel["flat_fee"])
    if channel.get("fee_percent") is not None:
        return round(amount * float(channel["fee_percent"]) / 100.0, 2)
    for t in channel.get("fee_tiers", []):
        if t["min"] <= amount <= t["max"]:
            return float(t["fee"])
    return None


@app.get("/api/health")
def health():
    return jsonify({"ok": True, "time": datetime.now(timezone.utc).isoformat()})


@app.get("/api/rates")
def rates():
    """Raw channel data (fees, rates, metadata)."""
    return jsonify(load_rates())


@app.get("/api/compare")
def compare():
    """Compare channels for a given THB amount. Sorted by best payout."""
    try:
        amount = float(request.args.get("amount", "10000"))
    except (TypeError, ValueError):
        return jsonify({"error": "invalid amount"}), 400
    if amount <= 0 or amount > 1000000:
        return jsonify({"error": "amount out of range"}), 400

    data = load_rates()
    out = []
    for ch in data.get("channels", []):
        fee = fee_for(ch, amount)
        if fee is None or fee >= amount:
            continue
        rate = float(ch["rate_thb_mmk"])
        received = int(round((amount - fee) * rate))
        out.append(
            {
                "id": ch["id"],
                "name": ch["name"],
                "name_my": ch.get("name_my", ch["name"]),
                "amount_thb": amount,
                "fee_thb": fee,
                "rate_thb_mmk": rate,
                "received_mmk": received,
                "transfer_time_my": ch.get("transfer_time_my", ""),
                "payout_my": ch.get("payout_my", ""),
                "notes_my": ch.get("notes_my", ""),
                "referral_url": ch.get("referral_url", ""),
                "verified": bool(ch.get("verified", False)),
            }
        )
    out.sort(key=lambda x: x["received_mmk"], reverse=True)
    return jsonify(
        {
            "amount_thb": amount,
            "updated_at": data.get("updated_at"),
            "disclaimer_my": data.get("disclaimer_my", ""),
            "results": out,
        }
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
