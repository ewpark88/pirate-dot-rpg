import 'package:game_data/src/models/common.dart';
import 'package:game_data/src/models/region_tables.dart';

/// 짧은 시나리오(docs/specs/economy-story.md, 사용자 요청 2026-10-17 '세계관을 잠깐, 보스 전 대화 — 스킵·자동 넘김, 전투는 계속').
/// 대사 한 줄: 말하는 이(`who` — speakers 중 하나) + 문구 키(`nameKey`, battle ARB).
typedef StoryLine = ({String who, String nameKey});

StoryLine _line(JsonReader j) => (who: j.str('who'), nameKey: j.str('nameKey'));

List<StoryLine> _lines(JsonReader j, String key) => j.objs(key).map(_line).toList();

/// 오프닝 한 컷: 그림 id(`art`) + 1~2줄.
typedef StoryCut = ({String art, List<StoryLine> lines});

class StoryTable {
  StoryTable.fromJson(JsonReader j)
    : lineSec = j.number('lineSec'),
      openingCutSec = j.number('openingCutSec'),
      speakers = j.strs('speakers').toSet(),
      opening = [for (final c in j.objs('opening')) (art: c.str('art'), lines: _lines(c, 'lines'))],
      bosses = {for (final e in j.obj('bosses').raw.keys) e: _lines(j.obj('bosses').obj(e), 'intro')},
      traitLines = {
        for (final tr in j.obj('traitLines').raw.keys)
          tr: [
            for (final set in j.obj('traitLines').raw[tr] as List)
              [for (final l in set as List) _line(JsonReader(l as Map<String, dynamic>, '${j.path}.traitLines.$tr'))],
          ],
      },
      outro = _lines(j, 'outro');

  /// 한 줄이 자동으로 넘어가기까지(초). 누르면 바로 다음, 스킵이면 끝 — 전투는 그동안에도 계속.
  final double lineSec;
  final double openingCutSec;
  final Set<String> speakers;
  final List<StoryCut> opening;

  /// 고유 대사(해역 보스·대보스): 보스 id → 등장 대사.
  final Map<String, List<StoryLine>> bosses;

  /// 공용 대사: 보스 특성(evade·armor…) 또는 'default' → 여러 벌.
  final Map<String, List<List<StoryLine>>> traitLines;

  /// 처치 뒤 한 줄(선택) — 여러 개 중 하나.
  final List<StoryLine> outro;

  /// 보스 등장 대사: 고유가 있으면 그것, 없으면 첫 특성의 공용(없으면 default) 중 [pick]번째(나머지로 돌림 — 스테이지 등).
  List<StoryLine> bossIntro(BossDef boss, int pick) {
    final own = bosses[boss.id];
    if (own != null) return own;
    final sets = traitLines[boss.traits.isEmpty ? 'default' : boss.traits.first.type] ?? traitLines['default']!;
    return sets[pick % sets.length];
  }

  List<String> validate(Set<String> bossIds) {
    final e = <String>[];
    expect(e, that: lineSec > 0 && openingCutSec > 0, message: 'story: lineSec·openingCutSec > 0');
    expect(e, that: opening.isNotEmpty, message: 'story: opening 컷이 있어야 함');
    expect(e, that: traitLines.containsKey('default'), message: 'story: traitLines.default 필요');
    final all = [
      for (final c in opening) ...c.lines,
      for (final ls in bosses.values) ...ls,
      for (final sets in traitLines.values)
        for (final s in sets) ...s,
      ...outro,
    ];
    for (final l in all) {
      expect(e, that: speakers.contains(l.who), message: 'story: ${l.nameKey}의 who ${l.who}가 speakers에 없음');
    }
    for (final id in bosses.keys) {
      expect(e, that: bossIds.contains(id), message: 'story: bosses의 $id가 regions.bosses에 없음');
    }
    for (final tr in traitLines.keys) {
      final known = tr == 'default' || BossTraitDef.types.contains(tr);
      expect(e, that: known && traitLines[tr]!.isNotEmpty, message: 'story: traitLines.$tr — 특성 종류가 아니거나 비었음');
    }
    return e;
  }
}
