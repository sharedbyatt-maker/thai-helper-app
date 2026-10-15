import copy
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
from werkzeug.security import generate_password_hash

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app

PASSWORD = 'temporary-test-password'
HEADERS = {'X-Admin-Request': '1'}


@pytest.fixture
def app(tmp_path):
    return create_app({'TESTING': True, 'DATABASE': str(tmp_path / 'rates.sqlite3'),
                       'ADMIN_PASSWORD_HASH': generate_password_hash(PASSWORD, method='pbkdf2:sha256:1000'),
                       'COOKIE_SECURE': False})


@pytest.fixture
def sheet():
    now = datetime.now(timezone.utc)
    return {'notice': 'Test quotes, not actual market rates', 'quotes': [
        {'id': 'test-thb', 'label': 'Test rate', 'direction': 'thb_mmk',
         'rate_micros': 125000000, 'flat_fee_minor': 1000, 'fee_bps': 100,
         'source_name': 'Test source', 'source_url': 'https://example.org/rates',
         'payout_method': 'Wallet', 'note': '', 'source_checked': True,
         'observed_at': now.isoformat(), 'valid_until': (now + timedelta(hours=12)).isoformat()}]}


def login(client):
    r = client.post('/api/admin/login', json={'password': PASSWORD}, headers=HEADERS)
    assert r.status_code == 200
    return {**HEADERS, 'X-CSRF-Token': r.json['csrf_token']}


def save(client, headers, sheet, version=0):
    return client.put('/api/admin/draft', json={'sheet': sheet, 'expected_version': version}, headers=headers)


def test_draft_is_private_and_publish_is_atomic(app, sheet):
    c = app.test_client()
    assert c.get('/api/v2/rates').json['quotes'] == []
    assert c.get('/api/admin/state').status_code == 401
    headers = login(c)
    assert save(c, headers, sheet).json['draft_version'] == 1
    assert c.get('/api/v2/rates').json['quotes'] == []
    published = c.post('/api/admin/publish', json={'expected_version': 1}, headers=headers)
    assert published.status_code == 200
    assert published.json['published']['revision'] == 1
    public = c.get('/api/v2/rates').json
    assert public['quotes'][0]['rate_micros'] == 125000000
    assert 'csrf_token' not in public
    assert c.post('/api/admin/publish', json={'expected_version': 1}, headers=headers).status_code == 409


def test_csrf_origin_and_logout(app, sheet):
    c = app.test_client()
    assert c.post('/api/admin/login', json={'password': PASSWORD}).status_code == 403
    assert c.post('/api/admin/login', json={'password': PASSWORD}, headers={**HEADERS, 'Origin': 'https://evil.test'}).status_code == 403
    headers = login(c)
    assert save(c, HEADERS, sheet).status_code == 403
    assert save(c, {**headers, 'X-CSRF-Token': 'wrong'}, sheet).status_code == 403
    assert c.post('/api/admin/logout', json={}, headers=headers).status_code == 200
    assert c.get('/api/admin/state').status_code == 401


def test_password_cookie_and_throttling(app):
    app.config['COOKIE_SECURE'] = True
    c = app.test_client()
    r = c.post('/api/admin/login', json={'password': PASSWORD}, headers=HEADERS)
    cookie = r.headers['Set-Cookie']
    assert all(x in cookie for x in ['HttpOnly', 'Secure', 'SameSite=Strict'])
    bad = app.test_client()
    for _ in range(8):
        assert bad.post('/api/admin/login', json=['bad'], headers=HEADERS).status_code == 401
    assert bad.post('/api/admin/login', json={'password': PASSWORD}, headers=HEADERS).status_code == 429


@pytest.mark.parametrize('key,value', [('rate_micros', float('nan')), ('rate_micros', True),
    ('rate_micros', 0), ('flat_fee_minor', -1), ('fee_bps', 10000),
    ('direction', 'both'), ('source_url', 'javascript:alert(1)'), ('source_url', 'http://['), ('source_checked', False),
    ('source_name', ''), ('valid_until', '2026-01-01'), ('observed_at', 'bad')])
def test_bad_quotes_return_400_not_500(app, sheet, key, value):
    c = app.test_client(); headers = login(c)
    sheet['quotes'][0][key] = value
    assert save(c, headers, sheet).status_code == 400
    assert c.get('/api/v2/rates').json['revision'] == 0


def test_malformed_sheets(app):
    c = app.test_client(); headers = login(c)
    for sheet in [None, [], {'quotes': 'not-list'}, {'quotes': [None]}]:
        assert save(c, headers, sheet).status_code == 400
    assert c.put('/api/admin/draft', json=[], headers=headers).status_code == 400


def test_expired_draft_cannot_publish(app, sheet):
    c = app.test_client(); headers = login(c)
    now = datetime.now(timezone.utc)
    sheet['quotes'][0]['observed_at'] = (now - timedelta(days=2)).isoformat()
    sheet['quotes'][0]['valid_until'] = (now - timedelta(days=1)).isoformat()
    assert save(c, headers, sheet).status_code == 200
    assert c.post('/api/admin/publish', json={'expected_version': 1}, headers=headers).status_code == 400


def test_restore_only_changes_draft_and_persists_restart(app, sheet):
    c = app.test_client(); headers = login(c)
    save(c, headers, sheet)
    c.post('/api/admin/publish', json={'expected_version': 1}, headers=headers)
    second = copy.deepcopy(sheet); second['quotes'][0]['rate_micros'] = 130000000
    save(c, headers, second, version=2)
    c.post('/api/admin/publish', json={'expected_version': 3}, headers=headers)
    assert c.post('/api/admin/restore', json={'revision': 1, 'expected_version': 4}, headers=headers).status_code == 200
    assert c.get('/api/v2/rates').json['quotes'][0]['rate_micros'] == 130000000
    c.post('/api/admin/publish', json={'expected_version': 5}, headers=headers)
    restarted = create_app({'TESTING': True, 'DATABASE': app.config['DATABASE']})
    public = restarted.test_client().get('/api/v2/rates').json
    assert public['revision'] == 3 and public['quotes'][0]['rate_micros'] == 125000000


def test_concurrent_edit_has_one_winner(app, sheet):
    def worker():
        with app.test_client() as c:
            return save(c, login(c), sheet).status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(lambda _: worker(), range(2))) == [200, 409]


def test_empty_publish_removes_rates_without_fabrication(app):
    c = app.test_client(); headers = login(c)
    assert save(c, headers, {'notice': 'Temporarily unavailable', 'quotes': []}).status_code == 200
    assert c.post('/api/admin/publish', json={'expected_version': 1}, headers=headers).status_code == 200
    assert c.get('/api/v2/rates').json['quotes'] == []


def test_no_default_admin_password(app):
    app.config['ADMIN_PASSWORD_HASH'] = ''
    c = app.test_client()
    assert c.post('/api/admin/login', json={'password': 'admin'}, headers=HEADERS).status_code == 503


def test_security_headers_and_public_cors(app):
    c = app.test_client()
    r = c.get('/admin')
    assert r.status_code == 200
    assert "frame-ancestors 'none'" in r.headers['Content-Security-Policy']
    assert r.headers['Cache-Control'] == 'no-store'
    assert c.get('/api/v2/rates').headers['Access-Control-Allow-Origin'] == '*'
    assert 'Access-Control-Allow-Origin' not in c.get('/api/admin/state').headers
    assert c.get('/api/missing').status_code == 404
    assert c.get('/api/click').status_code == 404


def test_changing_password_hash_revokes_sessions(app):
    c = app.test_client(); login(c)
    app.config['ADMIN_PASSWORD_HASH'] = generate_password_hash('another-password', method='pbkdf2:sha256:1000')
    assert c.get('/api/admin/state').status_code == 401
