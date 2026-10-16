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
