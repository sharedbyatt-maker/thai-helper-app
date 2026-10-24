import 'package:flutter/foundation.dart' show kIsWeb;

const legacyAppUrl = 'https://sharedbyatt-maker.github.io/thai-helper-app/';
const configuredAppUrl = String.fromEnvironment('PUBLIC_APP_URL', defaultValue: legacyAppUrl);

/// Web links follow the current deployment's app root. Native releases use
/// the explicitly configured production URL; no user records are moved.
String resolveAppUrl({required Uri page, required bool web, String configured = configuredAppUrl}) {
  if (web && (page.scheme == 'https' || page.scheme == 'http')) {
    return page.resolve('./').toString();
  }
  final target = Uri.tryParse(configured);
  if (target == null || target.scheme != 'https' || target.host.isEmpty || target.userInfo.isNotEmpty || target.hasQuery || target.hasFragment) {
    return legacyAppUrl;
  }
  return configured.endsWith('/') ? configured : '$configured/';
}
String get publicAppUrl => resolveAppUrl(page: Uri.base, web: kIsWeb);
