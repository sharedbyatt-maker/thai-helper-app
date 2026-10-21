import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_helper/exchange/platform_files_native.dart';

void main() {
  test(
    'Native backup picker cancellation is harmless; selected UTF-8 is unchanged',
    () async {
      expect(await pickBackup(select: () async => null), isNull);
      const raw = '{"name":"ဘတ်ဈေး","schema_version":1}';
      final picked = await pickBackup(
        select: () async =>
            XFile.fromData(Uint8List.fromList(utf8.encode(raw))),
      );
      expect(picked, raw);
    },
  );
  test(
    'Native oversized backup is rejected before parsing or restore',
    () async {
      await expectLater(
        pickBackup(select: () async => XFile.fromData(Uint8List(2000001))),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
