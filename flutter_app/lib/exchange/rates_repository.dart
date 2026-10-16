import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'rate_history.dart';

enum SheetOrigin { server, cache, bundled }

class LoadedSheet {
  final QuoteSheet sheet;
  final SheetOrigin origin;
  const LoadedSheet(this.sheet, this.origin);
}

class RatesRepository {
  static const apiBase = String.fromEnvironment('RATES_API');
  static const cacheKey = 'published_exchange_sheet_v2';
  final http.Client client;
  final Future<SharedPreferences> Function() preferences;
  RatesRepository({
    http.Client? client,
    Future<SharedPreferences> Function()? preferences,
  }) : client = client ?? http.Client(),
       preferences = preferences ?? SharedPreferences.getInstance;
  Future<SharedPreferences?> _preferences() async {
    try {
      return await preferences().timeout(const Duration(seconds: 1));
    } catch (_) {
      return null;
    }
  }

  Uri get endpoint => apiBase.isEmpty
      ? Uri.base.resolve('/api/v2/rates')
      : Uri.parse('$apiBase/api/v2/rates');
  Future<LoadedSheet> load() async {
    final pendingPreferences = _preferences();
    try {
      final response = await client
          .get(
            endpoint.replace(
              queryParameters: {
                ...endpoint.queryParameters,
                'v': DateTime.now().millisecondsSinceEpoch.toString(),
              },
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const FormatException('Server unavailable');
      }
      final sheet = QuoteSheet.decode(response.body);
      // Valid server data remains usable if storage is full/blocked.
      try {
        await (await pendingPreferences)?.setString(cacheKey, response.body);
      } catch (_) {
        /* optional cache */
      }
      return LoadedSheet(sheet, SheetOrigin.server);
    } catch (_) {
      String? cache;
      try {
        cache = (await pendingPreferences)?.getString(cacheKey);
      } catch (_) {}
      if (cache != null) {
        try {
          return LoadedSheet(QuoteSheet.decode(cache), SheetOrigin.cache);
        } catch (_) {
          /* bundled fallback */
        }
      }
      return LoadedSheet(
        QuoteSheet.decode(
          await rootBundle.loadString('assets/data/exchange_snapshot.json'),
        ),
        SheetOrigin.bundled,
      );
    }
  }

  Future<RateHistory> loadHistory() async {
    const key = 'published_rate_history_v1';
    final pendingPreferences = _preferences();
    try {
      final uri = endpoint.replace(
        path: '/api/v2/history',
        queryParameters: {
          'v': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final r = await client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) {
        throw const FormatException('History unavailable');
      }
      final result = RateHistory.decode(r.body);
      try {
        await (await pendingPreferences)?.setString(key, r.body);
      } catch (_) {
        /* optional cache */
      }
      return result;
    } catch (_) {
      try {
        final raw = (await pendingPreferences)?.getString(key);
        if (raw != null) return RateHistory.decode(raw, cached: true);
      } catch (_) {
        /* an invalid optional cache must not crash the dashboard */
      }
      rethrow;
    }
  }

  void close() => client.close();
}
