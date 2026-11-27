import 'package:flutter_nb_net/flutter_net.dart';

class UpdateInfoModel extends BaseNetModel {
  @override
  UpdateInfoModel fromJson(Map<String, dynamic> json) {
    return UpdateInfoModel.fromJson(json);
  }

  UpdateInfoModel({
    this.isUpdate,
    this.branch,
    this.currentCommit,
    this.latestCommit,
    this.commit,
  });

  UpdateInfoModel.fromJson(dynamic json) {
    if (json is! Map) {
      return;
    }
    final rawUpdate = json['is_update'];
    isUpdate = rawUpdate is bool ? rawUpdate : null;
    branch = json['branch']?.toString();
    currentCommit = _toStringList(json['current_commit']);
    latestCommit = _toStringList(json['latest_commit']);
    final rawCommits = json['commit'];
    if (rawCommits is List) {
      commit = rawCommits
          .whereType<List>()
          .map((item) => item.map((e) => e?.toString() ?? '').toList())
          .toList();
    } else {
      commit = <List<String>>[];
    }
  }

  bool? isUpdate;
  String? branch;
  List<String>? currentCommit;
  List<String>? latestCommit;
  List<List<String>>? commit;

  bool get hasValidData =>
      isUpdate != null &&
      (currentCommit?.isNotEmpty ?? false) &&
      (latestCommit?.isNotEmpty ?? false);

  static List<String>? _toStringList(dynamic value) {
    if (value is! List) {
      return null;
    }
    return value.map((e) => e?.toString() ?? '').toList();
  }
}
