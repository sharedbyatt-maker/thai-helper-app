# Rates Backend (Flask)

## Run locally
```
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python app.py   # http://localhost:5000
```

## Endpoints
- `GET /api/health`
- `GET /api/rates` — raw channel data
- `GET /api/compare?amount=10000` — sorted comparison

## Update rates (v1: manual)
Edit `rates.json`:
- `rate_thb_mmk` per channel (check TrueMoney/WU counters or their sites)
- `updated_at` to now
- `verified: true` once you confirm a channel's numbers
- restart the app

## Deploy
Any Python host (Railway/Render/VPS):
```
gunicorn app:app
```
Then rebuild the Flutter web app with:
```
flutter build web --release --base-href /thai-helper-app/ \
  --dart-define=RATES_API=https://your-api-host
```
Without RATES_API the app uses the bundled `rates_snapshot.json`
(manually synced from `backend/rates.json`).

## Legal note
Information only. This service does not transmit money.
