import 'package:game_core/src/battle/spawner.dart' show bossAttack, bossMaxHp;
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

/// 도감 보스 한 칸(사용자 지시 2026-10-18 '보스 능력치 노출' — S4 화면): 표에서 그 보스가 처음 나오는 스테이지와
/// 그 스테이지 기준 체력·공격, 특성·약점(카운터 계열)·패턴, 이 세이브의 만남·처치 수.
@immutable
class BossDexEntry {
  const BossDexEntry({
    required this.id,
    required this.nameKey,
    required this.firstStage,
    required this.hp,
    required this.attack,
    required this.traits,
    required this.weakFamilies,
    required this.patterns,
    required this.seen,
    required this.kills,
  });

  final String id;
  final String nameKey;

  /// 표에서 처음 나오는 스테이지(회전·중간·해역·벽 보스 자리 중 가장 앞, 한 바퀴 안). 안 나오면 0(러시 전용 등).
  final int firstStage;

  /// [firstStage] 기준 보스 체력·공격(초반 감쇠·장면 배율 없음 — 도감에 쓰는 기준값).
  final BigNum hp;
  final BigNum attack;

  /// 특성 type(evade·armor·regen·reflect·enrage·escort·dash) · 그 특성을 잘 깨는 계열 + 보스 약점 계열 · 패턴 type.
  final List<String> traits;
  final List<String> weakFamilies;
  final List<String> patterns;

  /// 만났나(그림자 공개) · 처치 수(1 이상이면 모습 공개).
  final bool seen;
  final int kills;
}

/// 모든 보스의 도감 칸 — 처음 나오는 스테이지 순(안 나오는 보스는 뒤).
List<BossDexEntry> bossDexView(GameState s, GameTables t) {
  final first = <String, int>{};
  final r = t.regions;
  for (var stage = 1; stage <= r.loopStages; stage++) {
    first.putIfAbsent(r.bossAt(stage).id, () => stage);
  }
  final dex = s.progress.dex;
  final rows = [
    for (final b in r.bosses.values)
      BossDexEntry(
        id: b.id,
        nameKey: b.nameKey,
        firstStage: first[b.id] ?? 0,
        hp: bossMaxHp(t, first[b.id] ?? 1, def: b),
        attack: bossAttack(t.waves, first[b.id] ?? 1),
        traits: [for (final x in b.traits) x.type],
        weakFamilies: {...b.weakFamilies, ...b.counterFamilies}.toList(),
        patterns: [for (final p in b.patterns) p.type],
        seen: dex.seen.contains(b.id) || dex.killsOf(b.id) > 0,
        kills: dex.killsOf(b.id),
      ),
  ];
  int key(BossDexEntry e) => e.firstStage == 0 ? r.loopStages + 1 : e.firstStage; // 안 나오는 보스는 뒤
  return rows..sort((a, b) => key(a).compareTo(key(b)));
}
