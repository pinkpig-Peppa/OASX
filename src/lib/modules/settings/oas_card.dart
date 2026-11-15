import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:styled_widget/styled_widget.dart';

import 'package:oasx/api/api_client.dart';
import 'package:oasx/config/design_tokens.dart';
import 'package:oasx/modules/home/tool_view.dart';
import 'package:oasx/modules/settings/controllers/settings_controller.dart';
import 'package:oasx/modules/settings/oas_card_extra.dart';
import 'package:oasx/modules/settings/widgets/setting_card.dart';
import 'package:oasx/modules/settings/widgets/setting_item.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/platform_utils.dart';

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

Future<void> exportDiagnostic() async {
  final exporting = true.obs;
  final resultPath = ''.obs;
  final failed = false.obs;

  Get.dialog(
    Obx(() {
      if (exporting.value) {
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
              Text(I18n.exportDiagnosticInProgress.tr),
            ],
          ),
        );
      }
      if (failed.value) {
        return AlertDialog(
          title: Text(I18n.exportDiagnostic.tr),
          content: Text(I18n.exportDiagnosticFailed.tr),
          actions: [
            TextButton(onPressed: Get.back, child: Text(I18n.confirm.tr)),
          ],
        );
      }
      return AlertDialog(
        title: Text(I18n.exportDiagnostic.tr),
        content: SelectableText(resultPath.value),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: resultPath.value));
              Get.snackbar(I18n.copySuccess.tr, '');
              Get.back();
            },
            child: Text(I18n.copy.tr),
          ),
          TextButton(onPressed: Get.back, child: Text(I18n.confirm.tr)),
        ],
      );
    }),
    barrierDismissible: false,
  );

  final data = await ApiClient().exportDiagnostic();
  exporting.value = false;
  if (data == null) {
    failed.value = true;
    return;
  }
  resultPath.value = (data['path'] ?? '').toString();
}

Future<void> doctor() async {
  final loading = true.obs;
  final report = Rxn<Map<String, dynamic>>();
  final failed = false.obs;

  Get.dialog(
    Obx(() {
      final data = report.value;
      if (loading.value) {
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
              Text(I18n.doctorRunning.tr),
            ],
          ),
        );
      }
      if (failed.value || data == null) {
        return AlertDialog(
          title: Text(I18n.doctor.tr),
          content: Text(I18n.doctorFailed.tr),
          actions: [
            TextButton(onPressed: Get.back, child: Text(I18n.confirm.tr)),
          ],
        );
      }
      final checks = (data['checks'] as List?) ?? const [];
      final summary = (data['summary'] as Map?) ?? const {};
      final passed = summary['pass'] ?? 0;
      final warns = summary['warn'] ?? 0;
      final fails = summary['fail'] ?? 0;
      return AlertDialog(
        title: Text('${I18n.doctor.tr}  $passed OK / $warns ! / $fails X'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: checks.map((item) => _doctorRow(item)).toList(),
            ),
          ).constrained(maxHeight: 420),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text(I18n.confirm.tr)),
        ],
      );
    }),
    barrierDismissible: false,
  );

  final data = await ApiClient().runDoctor();
  loading.value = false;
  if (data == null) {
    failed.value = true;
    return;
  }
  report.value = data;
}

Widget _doctorRow(dynamic item) {
  final check = Map<String, dynamic>.from(item as Map);
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
