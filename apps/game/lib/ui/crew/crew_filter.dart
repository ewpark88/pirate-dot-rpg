import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';

// 도감 정렬·필터 (사용자 직접 지시 2026-10-16): 등급별 / 공격력(초당)별 / 특성별(계열·조준·범위·명중 — 개성 v2 아이콘과 같은 기준),
// 보유·미보유, '합치기 가능'만 보기. 선원 탭 격자와 편성 고르기에서 같은 [CrewQuery]를 쓴다.

enum CrewSort { number, rarity, dps }

enum OwnedFilter { all, owned, unowned }

/// 정렬·필터 조건 (실행 동안 기억, ==).
@immutable
class CrewQuery {
  const CrewQuery({
    this.sort = CrewSort.number,
    this.owned = OwnedFilter.all,
    this.family,
    this.aim,
    this.area,
    this.hit,
    this.upOnly = false,
  });

  final CrewSort sort;
  final OwnedFilter owned;
  final String? family;
  final AimKind? aim;
  final bool? area;
  final HitKind? hit;

  /// 합치기로 레벨이 오르는 선원만.
  final bool upOnly;

  /// 켜진 특성 필터 수 (버튼 숫자).
  int get traitCount => [family, aim, area, hit].where((v) => v != null).length;

  CrewQuery copyWith({
    CrewSort? sort,
    OwnedFilter? owned,
    String? Function()? family,
    AimKind? Function()? aim,
    bool? Function()? area,
    HitKind? Function()? hit,
    bool? upOnly,
  }) => CrewQuery(
    sort: sort ?? this.sort,
    owned: owned ?? this.owned,
    family: family == null ? this.family : family(),
    aim: aim == null ? this.aim : aim(),
    area: area == null ? this.area : area(),
    hit: hit == null ? this.hit : hit(),
    upOnly: upOnly ?? this.upOnly,
  );

  @override
  bool operator ==(Object other) =>
      other is CrewQuery &&
      other.sort == sort &&
      other.owned == owned &&
      other.family == family &&
      other.aim == aim &&
      other.area == area &&
      other.hit == hit &&
      other.upOnly == upOnly;

  @override
  int get hashCode => Object.hash(sort, owned, family, aim, area, hit, upOnly);
}

final crewQueryProvider = NotifierProvider<CrewQueryNotifier, CrewQuery>(CrewQueryNotifier.new);

class CrewQueryNotifier extends Notifier<CrewQuery> {
  @override
  CrewQuery build() => const CrewQuery();

  // 조건 바꾸기는 copyWith 한 번(동작 이름으로 부른다).
  // ignore: use_setters_to_change_properties
  void set(CrewQuery q) => state = q;

  void reset() => state = CrewQuery(sort: state.sort);
}

/// 합치기로 레벨이 오르는 선원 id (경제 canLevelUp — 일괄 합치기와 같은 판정).
Set<String> levelUpIds(GameState s, GameTables t) {
  final max = crewMaxLevel(s, t);
  return {
    for (final e in s.crews.entries)
      if (canLevelUp(e.value, t, maxLevel: max)) e.key,
  };
}

/// 조건에 맞는 선원 목록 (정렬까지).
List<CrewDef> queryCrews(GameState s, GameTables t, CrewQuery q) {
  final up = q.upOnly ? levelUpIds(s, t) : const <String>{};
  final list = [
    for (final c in t.crews.crews)
      if (_match(s, t, q, c, up)) c,
  ];
  int rarityOf(CrewDef c) {
    final crew = s.crews[c.id];
    final r = crew == null ? t.rarities.byId(c.baseRarity) : rarityOfLevel(t.rarities, crew.level);
    return t.rarities.rarities.indexOf(r);
  }

  switch (q.sort) {
    case CrewSort.number:
      list.sort((a, b) => a.num.compareTo(b.num));
    case CrewSort.rarity:
      // 높은 등급 먼저, 같으면 레벨 높은 순, 그다음 번호.
      list.sort((a, b) {
        final r = rarityOf(b).compareTo(rarityOf(a));
        if (r != 0) return r;
        final l = (s.crews[b.id]?.level ?? 0).compareTo(s.crews[a.id]?.level ?? 0);
        return l != 0 ? l : a.num.compareTo(b.num);
      });
    case CrewSort.dps:
      // 보유 선원 혼자의 초당 피해(경제 fleetDps) 큰 순, 미보유는 뒤(번호순).
      final dps = {
        for (final c in list)
          if (s.crews.containsKey(c.id)) c.id: fleetDps(s, t, [c.id]),
      };
      list.sort((a, b) {
        final da = dps[a.id];
        final db = dps[b.id];
        if (da == null || db == null) {
          if (da != null) return -1;
          if (db != null) return 1;
          return a.num.compareTo(b.num);
        }
        return db.compareTo(da);
      });
  }
  return list;
}

bool _match(GameState s, GameTables t, CrewQuery q, CrewDef c, Set<String> up) {
  final owned = s.crews.containsKey(c.id);
  if (q.owned == OwnedFilter.owned && !owned) return false;
  if (q.owned == OwnedFilter.unowned && owned) return false;
  if (q.upOnly && !up.contains(c.id)) return false;
  if (q.family != null && c.family != q.family) return false;
  if (q.traitCount == (q.family == null ? 0 : 1)) return true;
  final id = crewIdentity(t, c.id);
  if (id == null) return false;
  if (q.aim != null && id.aim != q.aim) return false;
  if (q.area != null && id.area != q.area) return false;
  if (q.hit != null && id.hit != q.hit) return false;
  return true;
}
