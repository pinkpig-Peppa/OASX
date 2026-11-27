import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/api/update_info_model.dart';
import 'package:oasx/service/app_update/installers/windows_update_installer.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/service/websocket_service.dart';

void main() {
  group('WebSocket URL normalization', () {
    test('buildWsUrl maps http and https schemes cleanly', () {
      expect(
        WebSocketService.buildWsUrl('http://127.0.0.1:22288', 'oas'),
        'ws://127.0.0.1:22288/ws/oas',
      );
      expect(
        WebSocketService.buildWsUrl('https://oas.example.com:8443', 'oas'),
        'wss://oas.example.com:8443/ws/oas',
      );
      expect(
        WebSocketService.buildWsUrl('127.0.0.1:22288', 'oas'),
        'ws://127.0.0.1:22288/ws/oas',
      );
      expect(
        WebSocketService.buildWsUrl('https://oas.example.com/api', 'cfg'),
        'wss://oas.example.com/api/ws/cfg',
      );
    });

    test('normalizeWebSocketUrl fixes legacy ws://https:// URLs', () {
      expect(
        WebSocketClient.normalizeWebSocketUrl('ws://https://host:8443/ws/a'),
        'wss://host:8443/ws/a',
      );
      expect(
        WebSocketClient.normalizeWebSocketUrl('ws://http://host:22288/ws/a'),
        'ws://host:22288/ws/a',
      );
    });
  });

  test('wsListener treats malformed brace-wrapped logs as plain logs', () {
    Get.testMode = true;
    Get.put(WebSocketService());
    addTearDown(Get.reset);
    final service = ScriptService(storage: _UnusedStorage());
    service.addScriptModel('test');
    expect(
      () => service.wsListener("{'not_json': True}", 'test'),
      returnsNormally,
    );
  });

  group('WindowsUpdateInstaller script safety', () {
    test('uses same-volume selective replacement with rollback', () {
      const installer = WindowsUpdateInstaller();
      final script = installer.buildUpdateScript(
        currentProcessId: 4321,
        installDirectory: r'E:\Apps\OASX',
        zipPath: r'C:\Users\me\AppData\Local\Temp\oasx_updates\v2.4.2\pkg.zip',
        executableName: 'oasx.exe',
      );
      expect(
        script,
        contains(r"$backupDir = Join-Path $installDir ('.oasx_update_backup_' + $processId)"),
      );
      expect(script, contains('Copy-Item -LiteralPath'));
      expect(script, contains('Restore-Backup'));
      expect(
        script,
        isNot(contains('Move-Item -LiteralPath \$installDir -Destination \$backupDir')),
      );
    });

    test('launcher escapes percent signs in batch arguments', () {
      const installer = WindowsUpdateInstaller();
      final launcher = installer.buildLauncherScript(
        powershellPath: r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
        scriptPath: r'C:\Temp\100%safe\pkg.ps1',
      );
      expect(launcher, contains(r'C:\Temp\100%%safe\pkg.ps1'));
    });
  });

  group('UpdateInfoModel defensive parsing', () {
    test('handles empty or malformed payloads without throwing', () {
      final empty = UpdateInfoModel.fromJson(null);
      expect(empty.hasValidData, isFalse);

      final partial = UpdateInfoModel.fromJson({'is_update': false});
      expect(partial.hasValidData, isFalse);

      final valid = UpdateInfoModel.fromJson({
        'is_update': true,
        'branch': 'master',
        'current_commit': ['abc', 'dev', '2026-11-27', 'msg'],
        'latest_commit': ['1234567890', 'dev', '2026-11-27', 'new'],
        'commit': [
          ['1234567890', 'dev', '2026-11-27', 'new'],
        ],
      });
      expect(valid.hasValidData, isTrue);
      expect(valid.branch, 'master');
      expect(valid.commit, hasLength(1));
    });
  });
}

class _UnusedStorage implements GetStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
