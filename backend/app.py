"""Currency quote publishing service. No payments or customer accounts are stored."""
import hashlib
import json
import os
import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from functools import wraps
from pathlib import Path
from urllib.parse import urlparse

from flask import Flask, g, jsonify, request, send_from_directory
from werkzeug.security import check_password_hash
from werkzeug.middleware.proxy_fix import ProxyFix

BASE = Path(__file__).resolve().parent
EMPTY_SHEET = {"schema_version": 2, "revision": 0, "published_at": None,
               "notice": "နှုန်းမတင်ရသေးပါ။ ကိုယ်ရထားတဲ့ဈေးနဲ့ တွက်နိုင်ပါတယ်။", "quotes": []}


class InvalidSheet(ValueError):
    pass


def timestamp(value, field):
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if result.tzinfo is None:
            raise ValueError()
        return result.astimezone(timezone.utc)
    except (ValueError, TypeError, AttributeError):
        raise InvalidSheet(f"{field}: timezone ပါသော date/time လိုပါသည်") from None


def validate_sheet(value, now=None):
    now = now or datetime.now(timezone.utc)
    if not isinstance(value, dict) or not isinstance(value.get("quotes"), list):
        raise InvalidSheet("quotes စာရင်း လိုပါသည်")
    if len(value["quotes"]) > 30:
        raise InvalidSheet("နှုန်း အများဆုံး ၃၀ ခုသာ တင်နိုင်ပါသည်")

    def text(obj, key, limit, required=False):
        v = obj.get(key, "")
        if not isinstance(v, str) or len(v.strip()) > limit or (required and not v.strip()):
            raise InvalidSheet(f"{key}: စာသားကို ပြန်စစ်ပါ")
        return v.strip()

    out = {"notice": text(value, "notice", 500), "quotes": []}
    ids = set()
    for item in value["quotes"]:
        if not isinstance(item, dict):
            raise InvalidSheet("နှုန်းတစ်ခုချင်းသည် object ဖြစ်ရပါမည်")
        q = {k: text(item, k, n, required) for k, n, required in [
            ("id", 80, True), ("label", 100, True), ("source_name", 150, True),
            ("source_url", 500, False), ("payout_method", 100, True), ("note", 500, False)]}
        if q["id"] in ids:
            raise InvalidSheet("နှုန်း ID ထပ်နေပါသည်")
        ids.add(q["id"])
        if item.get("direction") not in ("thb_mmk", "mmk_thb"):
            raise InvalidSheet("ဘတ်ပေး / ကျပ်ပေး ကိုရွေးပါ")
        q["direction"] = item["direction"]
        for key, lower, upper in [("rate_micros", 1, 1_000_000_000_000),
                                  ("flat_fee_minor", 0, 100_000_000_000), ("fee_bps", 0, 9999)]:
            v = item.get(key, 0)
            if type(v) is not int or not lower <= v <= upper:
                raise InvalidSheet(f"{key}: ပမာဏ မမှန်ပါ")
            q[key] = v
        observed = timestamp(item.get("observed_at"), "စစ်ဆေးချိန်")
        expires = timestamp(item.get("valid_until"), "သက်တမ်းကုန်ချိန်")
        if observed > now + timedelta(minutes=5):
            raise InvalidSheet("စစ်ဆေးချိန်သည် အနာဂတ် မဖြစ်ရပါ")
        if expires <= observed or expires > observed + timedelta(days=7):
            raise InvalidSheet("သက်တမ်းသည် စစ်ဆေးချိန်နောက်၊ အများဆုံး ၇ ရက် ဖြစ်ရပါမည်")
        q["observed_at"], q["valid_until"] = observed.isoformat(), expires.isoformat()
        try:
            url = urlparse(q["source_url"])
        except ValueError:
            raise InvalidSheet("Source link မမှန်ပါ") from None
        if q["source_url"] and (url.scheme not in ("http", "https") or not url.netloc or url.username or url.password):
            raise InvalidSheet("Source link သည် http/https link ဖြစ်ရပါမည်")
        if item.get("source_checked") is not True:
            raise InvalidSheet("Source ကို စစ်ပြီးကြောင်း အမှန်ခြစ်ပေးပါ")
        q["source_checked"] = True
        out["quotes"].append(q)
    return out


def create_app(config=None):
    app = Flask(__name__, static_folder=None)
    app.config.update(
        DATABASE=os.environ.get("EXCHANGE_DATABASE", str(BASE / "instance" / "exchange.sqlite3")),
        ADMIN_PASSWORD_HASH=os.environ.get("ADMIN_PASSWORD_HASH", ""),
        COOKIE_SECURE=os.environ.get("COOKIE_SECURE", "true").lower() == "true",
        WEB_BUILD=os.environ.get("WEB_BUILD", str(BASE.parent / "flutter_app" / "build" / "web")),
        MAX_CONTENT_LENGTH=128 * 1024)
    if config:
        app.config.update(config)
    if os.environ.get("TRUST_PROXY", "false").lower() == "true":
        app.wsgi_app = ProxyFix(app.wsgi_app, x_for=0, x_proto=1, x_host=0)
    Path(app.config["DATABASE"]).parent.mkdir(parents=True, exist_ok=True)

    def db():
        if "db" not in g:
            g.db = sqlite3.connect(app.config["DATABASE"], timeout=15)
            g.db.row_factory = sqlite3.Row
        return g.db

    @app.teardown_appcontext
    def close_db(_error):
        if "db" in g:
            g.db.close()

    with app.app_context():
        db().executescript("""
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS revisions (
          id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT NOT NULL, published_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS draft (
          id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL, version INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS sessions (
          token_hash TEXT PRIMARY KEY, csrf TEXT NOT NULL, expires REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS login_attempts (ip TEXT NOT NULL, ts REAL NOT NULL);
        CREATE INDEX IF NOT EXISTS login_attempt_time ON login_attempts(ip, ts);
        """)
        db().execute("INSERT OR IGNORE INTO draft VALUES (1, ?, 0)", (json.dumps({"notice": "", "quotes": []}),))
        db().commit()

    def public_sheet():
        row = db().execute("SELECT * FROM revisions ORDER BY id DESC LIMIT 1").fetchone()
        if row is None:
            return dict(EMPTY_SHEET)
        return {**json.loads(row["payload"]), "schema_version": 2,
                "revision": row["id"], "published_at": row["published_at"]}

    def auth_required(fn):
        @wraps(fn)
        def decorated(*args, **kwargs):
            if not app.config["ADMIN_PASSWORD_HASH"]:
                return jsonify(error="Admin login မဖွင့်ရသေးပါ။ Server configuration လိုပါသည်။"), 503
            digest = hashlib.sha256((request.cookies.get("exchange_admin", "") + app.config["ADMIN_PASSWORD_HASH"]).encode()).hexdigest()
            sess = db().execute("SELECT * FROM sessions WHERE token_hash=? AND expires>?",
                                (digest, datetime.now(timezone.utc).timestamp())).fetchone()
            if not sess:
                return jsonify(error="အကောင့် ပြန်ဝင်ပါ"), 401
            if request.method != "GET" and not secrets.compare_digest(request.headers.get("X-CSRF-Token", ""), sess["csrf"]):
                return jsonify(error="စာမျက်နှာကို reload လုပ်ပြီး ပြန်စမ်းပါ"), 403
            g.admin_session = sess
            return fn(*args, **kwargs)
        return decorated

    @app.before_request
    def same_origin_admin():
        if request.path.startswith("/api/admin/") and request.method != "GET":
            origin = request.headers.get("Origin")
            if origin and origin.rstrip("/") != request.host_url.rstrip("/"):
                return jsonify(error="Cross-origin admin requests are not allowed"), 403
            if request.headers.get("X-Admin-Request") != "1":
                return jsonify(error="Admin request header required"), 403

    @app.after_request
    def headers(response):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        if request.path.startswith(("/admin", "/api/admin")):
            response.headers["Cache-Control"] = "no-store"
            response.headers["Content-Security-Policy"] = (
                "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; "
                "img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
        elif request.path in ("/api/v2/rates", "/api/rates"):
            response.headers["Access-Control-Allow-Origin"] = "*"
            response.headers["Cache-Control"] = "no-cache"
        return response

    @app.errorhandler(413)
    def oversized(_error):
        return jsonify(error="ပို့သောဒေတာ ပမာဏကြီးလွန်းပါသည်"), 413

    @app.get("/api/health")
    def health():
        db().execute("SELECT 1")
        return jsonify(ok=True)

    @app.get("/api/rates")
    @app.get("/api/v2/rates")
    def rates():
        return jsonify(public_sheet())

    @app.post("/api/admin/login")
    def login():
        password_hash = app.config["ADMIN_PASSWORD_HASH"]
        if not password_hash:
            return jsonify(error="ADMIN_PASSWORD_HASH မသတ်မှတ်ရသေးပါ"), 503
        now = datetime.now(timezone.utc).timestamp()
        ip = request.remote_addr or "unknown"
        conn = db()
        conn.execute("BEGIN IMMEDIATE")
        conn.execute("DELETE FROM login_attempts WHERE ts<?", (now - 900,))
        count = conn.execute("SELECT count(*) FROM login_attempts WHERE ip=?", (ip,)).fetchone()[0]
        if count >= 8:
            conn.commit()
            return jsonify(error="ဝင်ရန် ကြိုးစားမှုများနေပါသည်။ ၁၅ မိနစ်နောက် ပြန်စမ်းပါ"), 429
        conn.execute("INSERT INTO login_attempts VALUES (?, ?)", (ip, now))
        conn.commit()
        body = request.get_json(silent=True)
        password = body.get("password") if isinstance(body, dict) else None
        if not isinstance(password, str) or len(password) > 1024 or not check_password_hash(password_hash, password):
            return jsonify(error="Password မမှန်ပါ"), 401
        raw, csrf = secrets.token_urlsafe(48), secrets.token_urlsafe(32)
        old_digest = hashlib.sha256((request.cookies.get("exchange_admin", "") + app.config["ADMIN_PASSWORD_HASH"]).encode()).hexdigest()
        conn.execute("DELETE FROM sessions WHERE expires<? OR token_hash=?", (now, old_digest))
        conn.execute("INSERT INTO sessions VALUES (?, ?, ?)", (hashlib.sha256((raw + password_hash).encode()).hexdigest(), csrf, now + 8 * 3600))
        conn.execute("DELETE FROM login_attempts WHERE ip=?", (ip,))
        conn.commit()
        response = jsonify(ok=True, csrf_token=csrf)
        response.set_cookie("exchange_admin", raw, max_age=8 * 3600, httponly=True,
                            secure=app.config["COOKIE_SECURE"], samesite="Strict", path="/")
        return response

    @app.post("/api/admin/logout")
    @auth_required
    def logout():
        db().execute("DELETE FROM sessions WHERE token_hash=?", (g.admin_session["token_hash"],))
        db().commit()
        response = jsonify(ok=True)
        response.delete_cookie("exchange_admin", path="/")
        return response

    @app.get("/api/admin/state")
    @auth_required
    def admin_state():
        row = db().execute("SELECT * FROM draft WHERE id=1").fetchone()
        history = db().execute("SELECT id, published_at FROM revisions ORDER BY id DESC LIMIT 50").fetchall()
        return jsonify(draft=json.loads(row["payload"]), draft_version=row["version"],
                       published=public_sheet(), history=[dict(x) for x in history], csrf_token=g.admin_session["csrf"])

    def mutation_body():
        data = request.get_json(silent=True)
        if not isinstance(data, dict) or type(data.get("expected_version")) is not int:
            raise InvalidSheet("Draft version လိုပါသည်။ Reload လုပ်ပါ။")
        return data

    def check_version(conn, version):
        row = conn.execute("SELECT * FROM draft WHERE id=1").fetchone()
        return row if row["version"] == version else None

    @app.put("/api/admin/draft")
    @auth_required
    def save_draft():
        try:
            data = mutation_body()
            sheet = validate_sheet(data.get("sheet"))
        except InvalidSheet as error:
            return jsonify(error=str(error)), 400
        conn = db()
        conn.execute("BEGIN IMMEDIATE")
        if check_version(conn, data["expected_version"]) is None:
            conn.rollback()
            return jsonify(error="အခြား window မှ ပြင်ထားပါသည်။ Reload လုပ်ပါ။"), 409
        conn.execute("UPDATE draft SET payload=?, version=version+1 WHERE id=1", (json.dumps(sheet),))
        conn.commit()
        return jsonify(ok=True, draft_version=data["expected_version"] + 1)

    @app.post("/api/admin/publish")
    @auth_required
    def publish():
        try:
            data = mutation_body()
        except InvalidSheet as error:
            return jsonify(error=str(error)), 400
        conn = db()
        conn.execute("BEGIN IMMEDIATE")
        row = check_version(conn, data["expected_version"])
        if row is None:
            conn.rollback()
            return jsonify(error="Draft ပြောင်းထားပါသည်။ Reload လုပ်ပါ။"), 409
        now = datetime.now(timezone.utc)
        try:
            sheet = validate_sheet(json.loads(row["payload"]), now)
            for q in sheet["quotes"]:
                if timestamp(q["valid_until"], "သက်တမ်း") <= now:
                    raise InvalidSheet("သက်တမ်းကုန်သောနှုန်း ပါနေပါသည်။ အချိန် ပြန်စစ်ပါ။")
        except InvalidSheet as error:
            conn.rollback()
            return jsonify(error=str(error)), 400
        conn.execute("INSERT INTO revisions(payload, published_at) VALUES (?, ?)", (json.dumps(sheet), now.isoformat()))
        conn.execute("UPDATE draft SET version=version+1 WHERE id=1")
        conn.commit()
        return jsonify(ok=True, published=public_sheet(), draft_version=data["expected_version"] + 1)

    @app.post("/api/admin/restore")
    @auth_required
    def restore():
        try:
            data = mutation_body()
            if type(data.get("revision")) is not int:
                raise InvalidSheet("Revision လိုပါသည်")
        except InvalidSheet as error:
            return jsonify(error=str(error)), 400
        conn = db()
        conn.execute("BEGIN IMMEDIATE")
        if check_version(conn, data["expected_version"]) is None:
            conn.rollback()
            return jsonify(error="Draft ပြောင်းထားပါသည်။ Reload လုပ်ပါ။"), 409
        row = conn.execute("SELECT payload FROM revisions WHERE id=?", (data["revision"],)).fetchone()
        if not row:
            conn.rollback()
            return jsonify(error="Revision မတွေ့ပါ"), 404
        conn.execute("UPDATE draft SET payload=?, version=version+1 WHERE id=1", (row["payload"],))
        conn.commit()
        return jsonify(ok=True, draft_version=data["expected_version"] + 1)

    @app.get("/admin")
    @app.get("/admin/")
    def dashboard():
        return send_from_directory(BASE / "admin", "index.html")

    @app.get("/admin/<path:filename>")
    def admin_asset(filename):
        return send_from_directory(BASE / "admin", filename)

    @app.get("/")
    @app.get("/<path:filename>")
    def web(filename="index.html"):
        if filename.startswith("api/"):
            return jsonify(error="Not found"), 404
        root = Path(app.config["WEB_BUILD"])
        if not root.is_dir():
            return "Web build မရှိသေးပါ။ README မှ build command ဖြင့်တည်ဆောက်ပါ။ Admin: /admin", 503
        return send_from_directory(root, filename)

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", 5000)))
