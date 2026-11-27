import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:styled_widget/styled_widget.dart';

import 'package:oasx/api/update_info_model.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/config/design_tokens.dart';

import 'package:oasx/translation/i18n_content.dart';

class UpdaterView extends StatefulWidget {
  const UpdaterView({super.key});

  @override
  State<UpdaterView> createState() => _UpdaterViewState();
}

class _UpdaterViewState extends State<UpdaterView> {
  late Future<UpdateInfoModel> _updateInfoFuture;

  @override
  void initState() {
    super.initState();
    _updateInfoFuture = ApiClient().getUpdateInfo();
  }

  void _reload() {
    setState(() {
      _updateInfoFuture = ApiClient().getUpdateInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UpdateInfoModel>(
      future: _updateInfoFuture,
      builder: (BuildContext context, AsyncSnapshot<UpdateInfoModel> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _emptyOrError(context, 'Error: ${snapshot.error}');
        }
        final data = snapshot.data;
        if (data == null || !data.hasValidData) {
          return _emptyOrError(context, I18n.noData.tr);
        }
        return SingleChildScrollView(
          child: content(data, context).paddingAll(Spacing.xl),
        );
      },
    );
  }

  Widget _emptyOrError(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: Spacing.md),
        TextButton(
          onPressed: _reload,
          child: Text(I18n.retry.tr),
        ),
      ],
    ).paddingAll(Spacing.xl);
  }

  Widget content(UpdateInfoModel data, BuildContext context) {
    final isUpdate = data.isUpdate ?? false;
    final branch = data.branch ?? '-';
    final currentCommit = data.currentCommit ?? const <String>[];
    final latestCommit = data.latestCommit ?? const <String>[];

    Widget title = <Widget>[
      isUpdate
          ? const Icon(Icons.cloud_download)
          : Icon(Icons.cloud_off, color: SemanticColors.success(context)),
      isUpdate
          ? Text(
              I18n.findOasNewVersion.tr,
              style: Theme.of(context).textTheme.titleMedium,
            )
          : Text(
              I18n.oasLatestVersion.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
      const SizedBox(width: Spacing.xl),
      Text(
        '${I18n.currentBranch.tr}: $branch',
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ).constrained(height: 26),
      TextButton(
        onPressed: () {
          ApiClient().getExecuteUpdate();
        },
        child: Text(I18n.executeUpdate.tr),
      ),
    ].toRow(
      crossAxisAlignment: CrossAxisAlignment.center,
      separator: const SizedBox(width: Spacing.smPlus),
    );
    Table differTable = Table(
      border: tableBorder(context),
      textBaseline: TextBaseline.alphabetic,
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        differHead(context),
        genTableRow(currentCommit, differ: true, localRepo: true),
        genTableRow(latestCommit, differ: true),
      ],
    );
    Widget scrollableTitle = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: title,
    );
    Widget scrollableDifferTable = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: differTable,
    );
    Table submitHistory = Table(
      border: tableBorder(context),
      columnWidths: historyColumnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: submitHistoryData(data, context),
    );
    Widget scrollableSubmitHistory = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: submitHistory,
    );
    return <Widget>[
      scrollableTitle,
      scrollableDifferTable,
      Text(
        I18n.detailedSubmissionHistory.tr,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      scrollableSubmitHistory,
    ].toColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      separator: const SizedBox(height: Spacing.smPlus),
    );
  }

  String sha1(String data) {
    final trimmed = data.trim();
    return trimmed.length > 7 ? trimmed.substring(0, 7) : trimmed;
  }

  String _cell(List<String> row, int index) {
    return index < row.length ? row[index] : '';
  }

  TableRow genTableRow(
    List<String> data, {
    bool differ = false,
    bool localRepo = false,
  }) {
    return TableRow(
      children: [
        Text(sha1(_cell(data, 0))).paddingAll(Spacing.smPlus),
        Text(_cell(data, 1)).paddingAll(Spacing.smPlus),
        Text(_cell(data, 2), overflow: TextOverflow.ellipsis, maxLines: 2)
            .paddingAll(Spacing.smPlus),
        Text(_cell(data, 3), overflow: TextOverflow.ellipsis, maxLines: 2)
            .paddingAll(Spacing.smPlus),
        if (differ)
          localRepo
              ? Text(I18n.localRepo.tr).paddingAll(Spacing.smPlus)
              : Text(I18n.remoteRepo.tr).paddingAll(Spacing.smPlus),
      ],
    );
  }

  /// 表格描边：跟随主题的分隔线色，避免固定灰在深色主题下发脏。
  TableBorder tableBorder(BuildContext context) => TableBorder.all(
        color: Surfaces.divider(context),
        width: 1,
        style: BorderStyle.solid,
      );
  Map<int, TableColumnWidth> get columnWidths => const {
    0: FixedColumnWidth(80.0),
    1: FixedColumnWidth(80.0),
    2: FixedColumnWidth(130.0),
    3: FixedColumnWidth(200.0),
    4: FixedColumnWidth(80.0),
  };

  Map<int, TableColumnWidth> get historyColumnWidths => const {
    0: FixedColumnWidth(80.0),
    1: FixedColumnWidth(80.0),
    2: FixedColumnWidth(130.0),
    3: FixedColumnWidth(280.0),
  };

  TableRow differHead(BuildContext context) => TableRow(
    children: [
      Text('SHA1', style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
      Text(I18n.author.tr, style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
      Text(I18n.submitTime.tr, style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
      Text(I18n.submitInfo.tr, style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
      Text('Repo', style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
    ],
  );

  TableRow historyHead(BuildContext context) => TableRow(
    children: [
      Text('SHA1', style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
      Text(I18n.author.tr, style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
      Text(I18n.submitTime.tr, style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
      Text(I18n.submitInfo.tr, style: Theme.of(context).textTheme.titleMedium)
          .paddingAll(Spacing.smPlus),
    ],
  );

  List<TableRow> submitHistoryData(UpdateInfoModel data, BuildContext context) {
    final commits = data.commit ?? const <List<String>>[];
    final result = commits.map(genHistoryTableRow).toList();
    result.insert(0, historyHead(context));
    return result;
  }

  TableRow genHistoryTableRow(List<String> data) {
    return TableRow(
      children: [
        Text(sha1(_cell(data, 0))).paddingAll(Spacing.smPlus),
        Text(_cell(data, 1)).paddingAll(Spacing.smPlus),
        Text(_cell(data, 2), overflow: TextOverflow.ellipsis, maxLines: 2)
            .paddingAll(Spacing.smPlus),
        Text(_cell(data, 3)).paddingAll(Spacing.smPlus),
      ],
    );
  }
}
