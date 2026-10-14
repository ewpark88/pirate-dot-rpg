import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';
import 'package:meta/meta.dart';

// 화면 상단 ‘다음 목표’와 도감 보너스 (설계서 4.5, 스펙 economy-m3-meta 규칙 7~8).

enum GoalKind { shipTier, partMilestone, collection, rebirth }

@immutable
class NextGoal {
  const NextGoal({required this.kind, required this.remaining, required this.progress, this.id});

  final GoalKind kind;

  /// shipTier: 배 등급 id, partMilestone: 부위 id.
  final String? id;

  /// 남은 양 (스테이지·레벨·선원 수).
  final int remaining;

  /// 진행률 0~1.
  final double progress;
}

/// 진행률이 가장 큰 목표 하나. 같으면 [GoalKind] 순서.
NextGoal? nextGoal(GameState s, GameTables t) {
  final goals = <NextGoal>[];
  final stage = s.progress.stage;

  final tiers = t.shipTiers.tiers;
  final next = tiers.where((x) => x.stage > stage);
  if (next.isNotEmpty) {
    final from = t.shipTiers.tierAt(stage).stage;
    final to = next.first;
    goals.add(
      NextGoal(
        kind: GoalKind.shipTier,
        id: to.id,
        remaining: to.stage - stage,
        progress: (stage - from) / (to.stage - from),
      ),
    );
  }

  NextGoal? part;
  for (final p in t.shipParts.parts) {
    final every = p.milestoneEvery;
    if (every == null) continue;
    final lv = s.ship.level(p.id);
    final g = NextGoal(
      kind: GoalKind.partMilestone,
      id: p.id,
      remaining: every - lv % every,
      progress: (lv % every) / every,
    );
    if (part == null || g.progress > part.progress) part = g;
  }
  if (part != null) goals.add(part);

  final c = collectionBonus(s, t);
  final nextAt = c.nextAt;
  if (nextAt != null) {
    final every = t.meta.raw.obj('collection').integer('every');
    goals.add(NextGoal(kind: GoalKind.collection, remaining: nextAt - c.owned, progress: (c.owned % every) / every));
  }

  final minStage = t.meta.rebirth.integer('minStage');
  if (s.progress.bestStage < minStage) {
    goals.add(
      NextGoal(
        kind: GoalKind.rebirth,
        remaining: minStage - s.progress.bestStage,
        progress: s.progress.bestStage / minStage,
      ),
    );
  }

  if (goals.isEmpty) return null;
  goals.sort((a, b) {
    final p = b.progress.compareTo(a.progress);
    return p != 0 ? p : a.kind.index.compareTo(b.kind.index);
  });
  return goals.first;
}

@immutable
class CollectionBonus {
  const CollectionBonus({required this.owned, required this.total, required this.attackBonus, this.nextAt});

  final int owned;
  final int total;

  /// 전체 공격력 % 보너스 (0.03 = +3%). 피해 합에 넣는 것은 전투 레인.
  final double attackBonus;

  /// 다음 보너스가 붙는 보유 수. 다 모았으면 null.
  final int? nextAt;
}

/// 도감 `every`명마다 `attackBonus`.
CollectionBonus collectionBonus(GameState s, GameTables t) {
  final c = t.meta.raw.obj('collection');
  final every = c.integer('every');
  final owned = s.collection.length;
  final total = t.crews.crews.length;
  final next = (owned ~/ every + 1) * every;
  return CollectionBonus(
    owned: owned,
    total: total,
    attackBonus: owned ~/ every * c.number('attackBonus'),
    nextAt: next <= total ? next : null,
  );
}
