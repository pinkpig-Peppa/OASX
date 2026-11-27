import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/config/global.dart';
import 'package:oasx/service/app_update/app_version_utils.dart';

void main() {
  test('all application version sources agree on 2.4.3', () async {
    expect(GlobalVar.version, 'v2.4.3');
    expect(await AppVersionUtils.getCurrentVersion(), 'v2.4.3');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 2.4.3+29'));
    expect(pubspec, contains('msix_version: 2.4.3.0'));
    expect(AppVersionUtils.compareVersion('v2.4.2', 'v2.4.3'), isTrue);
  });
}
