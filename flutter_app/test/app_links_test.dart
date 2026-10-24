import 'package:flutter_test/flutter_test.dart';
import 'package:thai_helper/exchange/app_links.dart';
void main() {
  test('Web links use the deployment root without leaking query or fragment', () {
    expect(resolveAppUrl(page: Uri.parse('https://app.example/?tab=wallet#private'), web: true), 'https://app.example/');
    expect(resolveAppUrl(page: Uri.parse('$legacyAppUrl?tab=wallet'), web: true), legacyAppUrl);
  });
  test('Native links require a configured HTTPS URL', () {
    expect(resolveAppUrl(page: Uri(), web: false, configured: 'https://app.example'), 'https://app.example/');
    expect(resolveAppUrl(page: Uri(), web: false, configured: 'javascript:evil'), legacyAppUrl);
  });
}
