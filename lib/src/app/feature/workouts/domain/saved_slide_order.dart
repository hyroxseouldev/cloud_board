/// A relative move survives unrelated additions/deletions on another device.
typedef SavedSlideMove = ({String id, String? beforeId, String? afterId});

List<String> readSavedSlideOrder(Object? value) => value is List
    ? value.whereType<String>().where(isSavedSlideId).toSet().toList()
    : [];

bool isSavedSlideId(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

/// Missing order uses the existing ID order. Unknown/new IDs append; stale IDs
/// never create slides. Neither names nor any slide content participate.
List<String> reconcileSavedSlideOrder(
  List<String> stored,
  Iterable<String> liveIds, {
  SavedSlideMove? move,
}) {
  final live = liveIds.where(isSavedSlideId).toSet();
  final result = stored.where(live.contains).toSet().toList();
  result.addAll(live.difference(result.toSet()).toList()..sort());
  if (move == null || !result.contains(move.id)) return result;
  result.remove(move.id);
  final before = result.indexOf(move.beforeId ?? '');
  final after = result.indexOf(move.afterId ?? '');
  result.insert(
    before >= 0
        ? before
        : after >= 0
        ? after + 1
        : result.length,
    move.id,
  );
  return result;
}
