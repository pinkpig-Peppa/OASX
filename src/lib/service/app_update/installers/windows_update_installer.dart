import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:oasx/api/github_release_model.dart';
import 'package:oasx/service/app_update/installers/app_update_installer.dart';
import 'package:oasx/service/app_update/models/app_update_plan.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/platform_utils.dart';

/// Applies Windows portable zip updates through an external PowerShell script.
class WindowsUpdateInstaller implements AppUpdateInstaller {
  /// Creates a Windows update installer.
  const WindowsUpdateInstaller();

  @override
  String get installActionKey => I18n.downloadAndUpdate;

  @override
  Future<bool> canInstallInApp() async {
    final platformUtils = PlatformUtils();
    return !await platformUtils.isInstalledFromMicrosoftStore();
  }

  @override
  Future<GithubReleaseAssetModel?> selectAsset(
      GithubReleaseModel release) async {
    final assets = release.assets ?? const <GithubReleaseAssetModel>[];
    for (final asset in assets) {
      final name = (asset.name ?? '').toLowerCase();
      if (name.contains('windows') && name.endsWith('.zip')) {
        return asset;
      }
    }
    return null;
  }

  @override
  Future<void> install(DownloadedUpdatePackage package) async {
    final currentProcessId = pid;
    final executablePath = Platform.resolvedExecutable;
    final installDirectory = File(executablePath).parent.path;
    final executableName = File(executablePath).uri.pathSegments.last;
    final scriptFile = File('${package.filePath}.ps1');
    final launcherFile = File('${package.filePath}.cmd');
    final powershellPath = _resolvePowerShellPath();
    final scriptContent = buildUpdateScript(
      currentProcessId: currentProcessId,
      installDirectory: installDirectory,
      zipPath: package.filePath,
      executableName: executableName,
    );
    final launcherContent = buildLauncherScript(
      powershellPath: powershellPath,
      scriptPath: scriptFile.path,
    );
    await scriptFile.writeAsString(scriptContent, encoding: utf8);
    await launcherFile.writeAsString(launcherContent, encoding: utf8);
    await Process.start(
      'cmd.exe',
      [
        '/c',
        'start',
        '',
        'cmd.exe',
        '/c',
        'call',
        launcherFile.path,
      ],
      runInShell: false,
      workingDirectory: scriptFile.parent.path,
    );
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      exit(0);
    });
  }

  /// Builds the Windows handoff script that safely applies the downloaded zip.
  ///
  /// Uses selective in-place replacement with a same-volume backup directory so
  /// updates work across drives (e.g. `%TEMP%` on `C:` and install on `D:`/`E:`),
  /// preserve non-package files such as `logs/`, handle nested zip roots, and
  /// automatically roll back on failure.
  @visibleForTesting
  String buildUpdateScript({
    required int currentProcessId,
    required String installDirectory,
    required String zipPath,
    required String executableName,
  }) {
    final installDirLiteral = _psLiteral(installDirectory);
    final zipPathLiteral = _psLiteral(zipPath);
    final executableLiteral = _psLiteral(executableName);
    return r'''
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'OASX Updater'
$processId = __PROCESS_ID__
$installDir = __INSTALL_DIR__
$zipPath = __ZIP_PATH__
$exeName = __EXE_NAME__
$workRoot = Join-Path ([System.IO.Path]::GetDirectoryName($zipPath)) 'windows_apply'
$stageDir = Join-Path $workRoot 'stage'
$backupDir = Join-Path $installDir ('.oasx_update_backup_' + $processId)
$targetExe = Join-Path $installDir $exeName
$backedUpNames = New-Object System.Collections.Generic.List[string]
$copiedNames = New-Object System.Collections.Generic.List[string]

function Write-Step($message) {
  Write-Host ('[OASX Updater] ' + $message)
}

function Restore-Backup {
  foreach ($name in $copiedNames) {
    $copiedTarget = Join-Path $installDir $name
    if (Test-Path -LiteralPath $copiedTarget) {
      Remove-Item -LiteralPath $copiedTarget -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  foreach ($name in $backedUpNames) {
    $backupItem = Join-Path $backupDir $name
    $restoreTarget = Join-Path $installDir $name
    if (Test-Path -LiteralPath $backupItem) {
      Move-Item -LiteralPath $backupItem -Destination $restoreTarget -Force -ErrorAction SilentlyContinue
    }
  }
  if (Test-Path -LiteralPath $backupDir) {
    Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

try {
Write-Step 'Waiting for OASX to exit...'
for ($index = 0; $index -lt 120; $index++) {
  if (-not (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
    break
  }
  Start-Sleep -Milliseconds 500
}

if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
  throw 'Timed out waiting for the running OASX process to exit.'
}

Write-Step 'Preparing update workspace...'
if (Test-Path -LiteralPath $workRoot) {
  Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $workRoot -Force | Out-Null

Write-Step 'Extracting update package...'
Expand-Archive -LiteralPath $zipPath -DestinationPath $stageDir -Force

if (-not (Test-Path -LiteralPath $stageDir)) {
  throw 'The extracted update directory does not exist.'
}

$stageRoot = $stageDir
$stagedExe = Join-Path $stageDir $exeName
if (-not (Test-Path -LiteralPath $stagedExe)) {
  $foundExe = Get-ChildItem -LiteralPath $stageDir -Filter *.exe -File -Recurse | Select-Object -First 1
  if ($null -eq $foundExe) {
    throw 'No executable was found in the extracted update package.'
  }
  $stageRoot = Split-Path -Parent $foundExe.FullName
  $exeName = Split-Path -Leaf $foundExe.FullName
  $targetExe = Join-Path $installDir $exeName
}

$stageItems = @(Get-ChildItem -LiteralPath $stageRoot -Force)
if ($stageItems.Count -eq 0) {
  throw 'The extracted update directory is empty.'
}

if (-not (Test-Path -LiteralPath $installDir)) {
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

Write-Step 'Backing up files to be replaced...'
if (Test-Path -LiteralPath $backupDir) {
  Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

foreach ($item in $stageItems) {
  $existingPath = Join-Path $installDir $item.Name
  if (Test-Path -LiteralPath $existingPath) {
    Move-Item -LiteralPath $existingPath -Destination (Join-Path $backupDir $item.Name) -Force
    $backedUpNames.Add($item.Name) | Out-Null
  }
}

Write-Step 'Installing updated files...'
foreach ($item in $stageItems) {
  $destPath = Join-Path $installDir $item.Name
  Copy-Item -LiteralPath $item.FullName -Destination $destPath -Recurse -Force
  $copiedNames.Add($item.Name) | Out-Null
}

if (-not (Test-Path -LiteralPath $targetExe)) {
  throw ('The updated executable was not found: ' + $targetExe)
}

if (Test-Path -LiteralPath $backupDir) {
  Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Step 'Starting updated OASX...'
Start-Process -FilePath $targetExe -ArgumentList '--skip-parent-console' -WorkingDirectory $installDir | Out-Null

Write-Step 'Update complete. Closing updater window...'
Start-Sleep -Milliseconds 800
exit 0
} catch {
  Write-Host ''
  Write-Host '[OASX Updater] Update failed. Attempting rollback...' -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Restore-Backup
  Write-Host ''
  Read-Host 'Press Enter to close this window'
  exit 1
}
'''
        .replaceFirst('__PROCESS_ID__', currentProcessId.toString())
        .replaceFirst('__INSTALL_DIR__', installDirLiteral)
        .replaceFirst('__ZIP_PATH__', zipPathLiteral)
        .replaceFirst('__EXE_NAME__', executableLiteral);
  }

  /// Converts a value into a PowerShell single-quoted literal.
  String _psLiteral(String value) {
    final escaped = value.replaceAll("'", "''");
    return "'$escaped'";
  }

  /// Builds the visible launcher command script that hosts the updater window.
  @visibleForTesting
  String buildLauncherScript({
    required String powershellPath,
    required String scriptPath,
  }) {
    final escapedPowerShellPath = _cmdEscape(powershellPath);
    final escapedScriptPath = _cmdEscape(scriptPath);
    return '''
@echo off
title OASX Updater
setlocal
"$escapedPowerShellPath" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$escapedScriptPath"
exit /b %errorlevel%
''';
  }

  /// Escapes a Windows command argument for use inside a batch file.
  String _cmdEscape(String value) {
    return value.replaceAll('%', '%%').replaceAll('"', '""');
  }

  /// Resolves the full PowerShell executable path for Windows.
  String _resolvePowerShellPath() {
    final systemRoot = Platform.environment['SystemRoot'];
    if (systemRoot == null || systemRoot.isEmpty) {
      return 'powershell.exe';
    }
    return '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
  }
}
