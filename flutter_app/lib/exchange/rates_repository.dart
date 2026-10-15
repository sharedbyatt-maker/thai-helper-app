import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

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
  RatesRepository({http.Client? client}) : client = client ?? http.Client();
  Uri get endpoint => apiBase.isEmpty
      ? Uri.base.resolve('/api/v2/rates')
      : Uri.parse('$apiBase/api/v2/rates');
  Future<LoadedSheet> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await client
          .get(endpoint, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const FormatException('Server unavailable');
      }
      final sheet = QuoteSheet.decode(response.body);
      // Valid server data remains usable if storage is full/blocked.
      try {
        await prefs.setString(cacheKey, response.body);
      } catch (_) {
        /* optional cache */
      }
      return LoadedSheet(sheet, SheetOrigin.server);
    } catch (_) {
      final cache = prefs.getString(cacheKey);
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

  void close() => client.close();
}
