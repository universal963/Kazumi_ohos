// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get trending => '推荐';

  @override
  String get timeline => '时间线';

  @override
  String get collect => '追番';

  @override
  String get my => '我的';

  @override
  String get liveFrom => '放送开始：';

  @override
  String votes(int num) {
    return '$num 人评分：';
  }

  @override
  String get bangumiRank => 'Bangumi 评分：';

  @override
  String get overview => '概览';

  @override
  String get comments => '吐槽';

  @override
  String get characters => '角色';

  @override
  String get reviews => '评论';

  @override
  String get staff => '制作人员';

  @override
  String get introduction => '简介';

  @override
  String get tag => '标签';

  @override
  String get loadMore => '加载更多';

  @override
  String get more => '更多';

  @override
  String get startWatching => '开始观看';
}
