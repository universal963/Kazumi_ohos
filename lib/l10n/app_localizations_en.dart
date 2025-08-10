// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get trending => 'Trending';

  @override
  String get timeline => 'Timeline';

  @override
  String get collect => 'Collects';

  @override
  String get my => 'My';

  @override
  String get liveFrom => 'Live from:';

  @override
  String votes(int num) {
    return '$num votes';
  }

  @override
  String get bangumiRank => 'Bangumi ranked:';

  @override
  String get overview => 'Overview';

  @override
  String get comments => 'Comments';

  @override
  String get characters => 'Characters';

  @override
  String get reviews => 'Reviews';

  @override
  String get staff => 'Staff';

  @override
  String get introduction => 'Introduction';

  @override
  String get tag => 'Tags';

  @override
  String get loadMore => 'Load more';

  @override
  String get more => 'More';

  @override
  String get startWatching => 'Start watching';
}
