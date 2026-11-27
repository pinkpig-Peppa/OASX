import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 应用源码中必须保留的资源文件清单（含 2.4.0 新增眼睑姿态图）。
const _kRequiredSourceAssets = <String>[
  'assets/Lato-Regular.ttf',
  'assets/images/Icon-app.ico',
  'assets/images/Icon-app.png',
  'assets/images/main_bg_muse.jpg',
  'assets/images/main_bg_muse_ambient.jpg',
  'assets/images/main_bg_muse_anim.webp',
  'assets/images/main_bg_muse_front_full.png',
  'assets/images/main_bg_muse_front_closed.png',
  'assets/images/main_bg_muse_front_eye_quarter.png',
  'assets/images/main_bg_muse_front_eye_half.png',
  'assets/images/main_bg_muse_front_eye_three_quarter.png',
  'assets/release.txt',
  'assets/splash/girl_closed.jpg',
  'assets/splash/girl_closed_wire.png',
  'assets/splash/girl_closed_wire_extended.png',
  'assets/splash/girl_corner_repair.png',
  'assets/splash/girl_eye_quarter.png',
  'assets/splash/girl_eye_half.png',
  'assets/splash/girl_eye_three_quarter.png',
  'assets/splash/girl_open.jpg',
  'assets/splash/girl_open_wire.png',
  'assets/splash/girl_open_wire_extended.png',
];

const _kPubspecDeclaredEntries = <String>[
  'assets/release.txt',
  'assets/images/Icon-app.png',
  'assets/images/Icon-app.ico',
  'assets/images/main_bg_muse.jpg',
  'assets/images/main_bg_muse_ambient.jpg',
  'assets/images/main_bg_muse_front_full.png',
  'assets/images/main_bg_muse_front_closed.png',
  'assets/images/main_bg_muse_front_eye_quarter.png',
  'assets/images/main_bg_muse_front_eye_half.png',
  'assets/images/main_bg_muse_front_eye_three_quarter.png',
  'assets/images/main_bg_muse_anim.webp',
  'assets/splash/',
  'assets/Lato-Regular.ttf',
];

void main() {
  test('pubspec and source tree preserve all required assets and eye poses', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final entry in _kPubspecDeclaredEntries) {
      expect(pubspec, contains(entry), reason: 'missing pubspec entry: $entry');
    }
    for (final path in _kRequiredSourceAssets) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'missing asset file: $path');
      if (path != 'assets/release.txt') {
        expect(file.lengthSync(), greaterThan(0), reason: 'empty asset: $path');
      }
    }

    // 若本地存在手工构建后的随包目录，则一并校验其 AssetManifest。
    const root = '../data/flutter_assets';
    final manifestBin = File('$root/AssetManifest.bin');
    if (manifestBin.existsSync()) {
      const codec = StandardMessageCodec();
      final after =
          codec.decodeMessage(
                ByteData.sublistView(manifestBin.readAsBytesSync()),
              )
              as Map<Object?, Object?>;
      for (final path in _kRequiredSourceAssets) {
        expect(
          after[path],
          [
            {'asset': path},
          ],
          reason: path,
        );
      }
      final manifestJson = File('$root/AssetManifest.json');
      if (manifestJson.existsSync()) {
        final json = jsonDecode(manifestJson.readAsStringSync()) as Map;
        expect(
          json['assets/images/main_bg_muse_front_closed.png'],
          ['assets/images/main_bg_muse_front_closed.png'],
        );
      }
    }
  });
}
