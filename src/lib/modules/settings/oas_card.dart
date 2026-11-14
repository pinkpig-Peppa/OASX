import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
        SettingItem(
          left: Text(I18n.exportDiagnostic.tr),
          right: const Icon(Icons.input_rounded),
          onTap: exportDiagnostic,
        ),
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
