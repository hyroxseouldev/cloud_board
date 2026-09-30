import 'package:freezed_annotation/freezed_annotation.dart';
part 'update_news.freezed.dart';

typedef InstalledRelease = ({String platform, String version, String build});

@freezed
abstract class UpdateNews with _$UpdateNews {
  const UpdateNews._();
  const factory UpdateNews({
    required String id,
    required String title,
    required String summary,
    required String date,
    required String version,
    required Map<String, String> builds,
    required List<UpdateNewsItem> items,
  }) = _UpdateNews;

  bool availableFor(InstalledRelease installed) {
    final minimumBuild = builds[installed.platform];
    final versionOrder = compareReleaseNumbers(installed.version, version);
    final buildOrder = minimumBuild == null
        ? null
        : compareReleaseNumbers(installed.build, minimumBuild);
    return versionOrder != null &&
        versionOrder >= 0 &&
        buildOrder != null &&
        buildOrder >= 0;
  }
}

@freezed
abstract class UpdateNewsItem with _$UpdateNewsItem {
  const factory UpdateNewsItem({required String title, required String body}) =
      _UpdateNewsItem;
}

// Numeric components handle web build numbers such as 82.10 without doubles.
int? compareReleaseNumbers(String left, String right) {
  final valid = RegExp(r'^\d+(?:\.\d+){0,3}$');
  if (!valid.hasMatch(left) || !valid.hasMatch(right)) return null;
  final a = left.split('.').map(int.tryParse).toList();
  final b = right.split('.').map(int.tryParse).toList();
  if (a.contains(null) || b.contains(null)) return null;
  for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
    final order = (i < a.length ? a[i]! : 0).compareTo(
      i < b.length ? b[i]! : 0,
    );
    if (order != 0) return order;
  }
  return 0;
}

@freezed
abstract class UpdateNewsState with _$UpdateNewsState {
  const UpdateNewsState._();
  const factory UpdateNewsState({
    @Default([]) List<UpdateNews> notes,
    @Default({}) Set<String> readIds,
  }) = _UpdateNewsState;
  bool get hasUnread => notes.any((note) => !readIds.contains(note.id));
}
