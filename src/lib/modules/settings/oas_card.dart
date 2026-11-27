import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:styled_widget/styled_widget.dart';

import 'package:oasx/api/api_client.dart';
import 'package:oasx/config/design_tokens.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/tool_view.dart';
import 'package:oasx/modules/settings/controllers/settings_controller.dart';
import 'package:oasx/modules/settings/oas_card_extra.dart';
import 'package:oasx/modules/settings/widgets/setting_card.dart';
import 'package:oasx/modules/settings/widgets/setting_item.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/platform_utils.dart';

bool _isExportingDiagnostic = false;
bool _isRunningDoctor = false;

class OasSettingsCard extends StatelessWidget {
  const OasSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingCard(
      title: 'OAS${I18n.setting.tr}',
      items: [
        SettingItem(
          left: Text(I18n.notifyTest.tr),
          right: const Icon(Icons.input_rounded),
          onTap: notifyTest,
        ),
        SettingItem(
          left: Text(I18n.exportDiagnostic.tr),
          right: const Icon(Icons.input_rounded),
          onTap: exportDiagnostic,
        ),
        SettingItem(
          left: Text(I18n.doctor.tr),
          right: const Icon(Icons.input_rounded),
          onTap: doctor,
        ),
        SettingItem(
          left: Text(I18n.autoRunScript.tr),
          right: const AutoScriptButton(),
        ),
        if (PlatformUtils.isDesktop)
          SettingItem(
            left: Text(I18n.setupDeploy.tr),
            right: const Icon(Icons.input_rounded),
            onTap: openDeploySetting,
          ),
        if (PlatformUtils.isDesktop)
          SettingItem(
            left: Text(I18n.autoDeploy.tr),
            right: const DeploySwitcher(),
          ),
        if (PlatformUtils.isDesktop)
          SettingItem(
            left: Text(I18n.autoLoginAfterDeploy.tr),
            right: const LoginAfterDeploySwitcher(),
          ),
        SettingItem(
          left: Text(I18n.updater.tr),
          right: const Icon(Icons.input_rounded),
          onTap: updater,
        ),
        SettingItem(
          left: Text(I18n.killOasServer.tr),
          right: const Icon(Icons.input_rounded),
          onTap: killServer,
        ),
      ],
    );
  }
}

void notifyTest() {
  Get.defaultDialog(
    title: I18n.notifyTest.tr,
    content: const NotifyTest(),
  );
}

void openDeploySetting() {
  Get.toNamed('/server');
}

String _resolveActiveConfigName() {
  if (!Get.isRegistered<HomeDashboardController>()) {
    return '';
  }
  return Get.find<HomeDashboardController>().activeScriptName.value.trim();
}

Future<void> exportDiagnostic() async {
  if (_isExportingDiagnostic) {
    return;
  }
  _isExportingDiagnostic = true;
  final configName = _resolveActiveConfigName();
  try {
    await Get.dialog<void>(
      _ExportDiagnosticDialog(
        request: () => ApiClient().exportDiagnosticResult(
          configName: configName,
        ),
      ),
      barrierDismissible: true,
    );
  } finally {
    _isExportingDiagnostic = false;
  }
}

Future<void> doctor() async {
  if (_isRunningDoctor) {
    return;
  }
  _isRunningDoctor = true;
  final configName = _resolveActiveConfigName();
  try {
    await Get.dialog<void>(
      _DoctorDialog(
        request: () => ApiClient().runDoctorResult(configName: configName),
      ),
      barrierDismissible: true,
    );
  } finally {
    _isRunningDoctor = false;
  }
}

class _ExportDiagnosticDialog extends StatefulWidget {
  const _ExportDiagnosticDialog({required this.request});

  final Future<ApiResult<Map<String, dynamic>>> Function() request;

  @override
  State<_ExportDiagnosticDialog> createState() =>
      _ExportDiagnosticDialogState();
}

class _ExportDiagnosticDialogState extends State<_ExportDiagnosticDialog> {
  bool _loading = true;
  String _resultPath = '';
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.request();
    if (!mounted) {
      return;
    }
    if (!res.isSuccess || res.data == null) {
      setState(() {
        _loading = false;
        _errorDetail = res.error?.trim();
      });
      return;
    }
    final path = (res.data!['path'] ?? '').toString().trim();
    if (path.isEmpty) {
      setState(() {
        _loading = false;
        _errorDetail = 'empty diagnostic path';
      });
      return;
    }
    setState(() {
      _loading = false;
      _resultPath = path;
      _errorDetail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AlertDialog(
        title: Text(I18n.exportDiagnostic.tr),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Spacing.sm),
            Flexible(child: Text(I18n.exportDiagnosticInProgress.tr)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.cancel.tr),
          ),
        ],
      );
    }
    if (_errorDetail != null) {
      final detail = _errorDetail!;
      final message = detail.isEmpty
          ? I18n.exportDiagnosticFailed.tr
          : '${I18n.exportDiagnosticFailed.tr}\n$detail';
      return AlertDialog(
        title: Text(I18n.exportDiagnostic.tr),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.confirm.tr),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(I18n.exportDiagnostic.tr),
      content: SelectableText(_resultPath),
      actions: [
        TextButton(
          onPressed: _resultPath.isEmpty
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  await Clipboard.setData(ClipboardData(text: _resultPath));
                  if (navigator.mounted && navigator.canPop()) {
                    navigator.pop();
                  }
                  Get.snackbar(I18n.copySuccess.tr, '');
                },
          child: Text(I18n.copy.tr),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(I18n.confirm.tr),
        ),
      ],
    );
  }
}

class _DoctorDialog extends StatefulWidget {
  const _DoctorDialog({required this.request});

  final Future<ApiResult<Map<String, dynamic>>> Function() request;

  @override
  State<_DoctorDialog> createState() => _DoctorDialogState();
}

class _DoctorDialogState extends State<_DoctorDialog> {
  bool _loading = true;
  Map<String, dynamic>? _report;
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await widget.request();
    if (!mounted) {
      return;
    }
    if (!res.isSuccess || res.data == null) {
      setState(() {
        _loading = false;
        _errorDetail = res.error?.trim();
      });
      return;
    }
    setState(() {
      _loading = false;
      _report = res.data;
      _errorDetail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AlertDialog(
        title: Text(I18n.doctor.tr),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Spacing.sm),
            Flexible(child: Text(I18n.doctorRunning.tr)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.cancel.tr),
          ),
        ],
      );
    }
    final data = _report;
    if (_errorDetail != null || data == null) {
      final detail = _errorDetail ?? '';
      final message = detail.isEmpty
          ? I18n.doctorFailed.tr
          : '${I18n.doctorFailed.tr}\n$detail';
      return AlertDialog(
        title: Text(I18n.doctor.tr),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.confirm.tr),
          ),
        ],
      );
    }

    final rawChecks = data['checks'];
    final checks = rawChecks is List
        ? rawChecks
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : const <Map<String, dynamic>>[];
    final rawSummary = data['summary'];
    final summary = rawSummary is Map ? rawSummary : const <dynamic, dynamic>{};
    final passed = summary['pass'] ?? 0;
    final warns = summary['warn'] ?? 0;
    final fails = summary['fail'] ?? 0;
    final availableWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = math.min(560.0, math.max(240.0, availableWidth * 0.85));

    return AlertDialog(
      title: Text('${I18n.doctor.tr}  $passed OK / $warns ! / $fails X'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: checks.isEmpty
                ? [Text(I18n.noData.tr)]
                : checks.map(_doctorRow).toList(),
          ),
        ).constrained(maxHeight: 420),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(I18n.confirm.tr),
        ),
      ],
    );
  }
}

Widget _doctorRow(Map<String, dynamic> check) {
  final status = (check['status'] ?? '').toString();
  final (IconData icon, Color color) = switch (status) {
    'pass' => (Icons.check_circle, Colors.green),
    'warn' => (Icons.warning_amber_rounded, Colors.orange),
    'fail' => (Icons.error, Colors.red),
    _ => (Icons.remove_circle_outline, Colors.grey),
  };
  final hint = (check['hint'] ?? '').toString();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (check['title'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                (check['detail'] ?? '').toString(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (hint.isNotEmpty)
                Text(
                  '- $hint',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DeploySwitcher extends StatelessWidget {
  const DeploySwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    return Obx(
      () => Switch(
        value: settingsController.autoDeploy.value,
        onChanged: (nv) => settingsController.updateAutoDeploy(nv),
      ),
    );
  }
}

class LoginAfterDeploySwitcher extends StatelessWidget {
  const LoginAfterDeploySwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    return Obx(
      () => Switch(
        value: controller.autoLoginAfterDeploy.value,
        onChanged: (nv) => controller.updateAutoLoginAfterDeploy(nv),
      ),
    );
  }
}
