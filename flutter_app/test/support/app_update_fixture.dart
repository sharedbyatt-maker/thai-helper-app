import 'package:thai_helper/exchange/app_updates.dart';

// Rate/layout tests isolate native package metadata and release networking.
// app_updates_test.dart exercises those boundaries with explicit fixtures.
AppUpdateService noNativeUpdates() => AppUpdateService(installedApp: () async => null);
