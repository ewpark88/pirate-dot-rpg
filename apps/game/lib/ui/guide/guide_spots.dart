import 'package:flutter/widgets.dart';

// 가이드 v2(docs/specs/ui-guide-v2.md): 가리키는 위젯(TutorialSpot)이 자기 자리를 여기에 걸어 두면, 가이드 층이 그 자리만 밝히고
// 손가락을 얹는다. 위치는 그릴 때마다 RenderBox에서 다시 읽는다(시트를 끌거나 탭을 굴려도 따라간다).

/// 지금 가리키는 id → 그 위젯의 키들 (같은 id가 두 곳에 있을 수 있다 — 예: 도크 아이콘이 시트 안팎에).
final Map<String, Set<GlobalKey>> _spots = {};

/// 가리키는 위젯 등록 / 해제 (TutorialSpot이 부른다).
void putGuideSpot(String id, GlobalKey key) => (_spots[id] ??= {}).add(key);

void removeGuideSpot(String id, GlobalKey key) {
  final keys = _spots[id];
  if (keys == null) return;
  keys.remove(key);
  if (keys.isEmpty) _spots.remove(id);
}

/// [ids] 순서대로, 화면에 붙어 있는 자리(전역 좌표). 크기가 0이거나 아직 안 그려진 것은 뺀다.
List<Rect> guideSpotRects(Iterable<String> ids) => [
  for (final id in ids)
    for (final key in _spots[id] ?? const <GlobalKey>{}) ?_rectOf(key),
];

Rect? _rectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
