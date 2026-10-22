import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_helper/exchange/rates_repository.dart';

final raw = jsonEncode({
  'schema_version': 2,
  'revision': 4,
  'published_at': '2026-10-15T09:00:00Z',
  'notice': '',
  'quotes': [],
});
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Actual response source is server on valid data', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = RatesRepository(
      client: MockClient((_) async => http.Response(raw, 200)),
    );
    final result = await repo.load();
    expect(result.origin, SheetOrigin.server);
    expect(result.sheet.revision, 4);
    repo.close();
  });
  test(
    'API failure uses last known data and explicitly reports cache',
    () async {
      SharedPreferences.setMockInitialValues({RatesRepository.cacheKey: raw});
      final repo = RatesRepository(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final result = await repo.load();
      expect(result.origin, SheetOrigin.cache);
      expect(result.sheet.revision, 4);
      repo.close();
    },
  );
  test(
    'Offline refresh retains the last live sheet when storage is blocked',
    () async {
      var online = true;
      final repo = RatesRepository(
        preferences: () async => throw StateError('blocked storage'),
        client: MockClient(
          (_) async =>
              http.Response(online ? raw : 'offline', online ? 200 : 503),
        ),
      );
      expect((await repo.load()).origin, SheetOrigin.server);
      online = false;
      final offline = await repo.load();
      expect(offline.origin, SheetOrigin.cache);
      expect(offline.sheet.revision, 4);
      repo.close();
    },
  );
  test(
    'A deliberate server withdrawal replaces the session fallback too',
    () async {
      var response = raw;
      var online = true;
      final repo = RatesRepository(
        preferences: () async => throw StateError('blocked storage'),
        client: MockClient(
          (_) async =>
              http.Response(online ? response : 'offline', online ? 200 : 503),
        ),
      );
      await repo.load();
      response = jsonEncode({
        'schema_version': 2,
        'revision': 5,
        'published_at': '2026-10-15T10:00:00Z',
        'notice': 'Withdrawn',
        'quotes': [],
      });
      expect((await repo.load()).sheet.revision, 5);
      online = false;
      expect((await repo.load()).sheet.revision, 5);
      repo.close();
    },
  );
  test(
    'An older overlapping response cannot replace the newer session fallback',
    () async {
      final first = Completer<http.Response>(),
          second = Completer<http.Response>();
      var calls = 0;
      final repo = RatesRepository(
        preferences: () async => throw StateError('blocked storage'),
        client: MockClient((_) {
          calls++;
          return calls == 1
              ? first.future
              : calls == 2
              ? second.future
              : Future.value(http.Response('offline', 503));
        }),
      );
      final older = repo.load(), newer = repo.load();
      second.complete(
        http.Response(raw.replaceFirst('"revision":4', '"revision":5'), 200),
      );
      await newer;
      first.complete(http.Response(raw, 200));
      await older;
      expect((await repo.load()).sheet.revision, 5);
      repo.close();
    },
  );
  test('Malformed API data does not replace a valid cache', () async {
    SharedPreferences.setMockInitialValues({RatesRepository.cacheKey: raw});
    final repo = RatesRepository(
      client: MockClient(
        (_) async => http.Response('{"schema_version":99}', 200),
      ),
    );
    expect((await repo.load()).origin, SheetOrigin.cache);
    expect(
      (await SharedPreferences.getInstance()).getString(
        RatesRepository.cacheKey,
      ),
      raw,
    );
    repo.close();
  });
  test(
    'Blocked browser storage does not prevent live rates or chart history',
    () async {
      final repo = RatesRepository(
        preferences: () async => throw StateError('blocked storage'),
        client: MockClient(
          (r) async => http.Response(
            r.url.path.endsWith('/history')
                ? jsonEncode({
                    'schema_version': 1,
                    'timezone': 'Asia/Bangkok',
                    'points': [],
                    'observations': [],
                  })
                : raw,
            200,
          ),
        ),
      );
      expect((await repo.load()).origin, SheetOrigin.server);
      expect((await repo.loadHistory()).points, isEmpty);
      repo.close();
    },
  );
  test(
    'Corrupt cached chart data is rejected without replacing cached rates',
    () async {
      SharedPreferences.setMockInitialValues({
        RatesRepository.cacheKey: raw,
        'published_rate_history_v1': 'broken',
      });
      final repo = RatesRepository(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      await expectLater(repo.loadHistory(), throwsA(isA<FormatException>()));
      expect((await repo.load()).sheet.revision, 4);
      repo.close();
    },
  );
}
// Cache/storage access is optional; online reads must still work in restricted browsers.
