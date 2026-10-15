import 'package:game_cli/src/balance/arena.dart';
import 'package:game_cli/src/balance/combos.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 대표 레벨 = 등급 5개 (rarityOfLevel 구간).
const defaultLevels = [15, 30, 45, 60, 75];

/// 같은 등급·레벨 중앙값 대비 허용 폭 (설계서 4.8).
const tolerance = 0.10;

/// 조합 상위 비율과 한도.
const comboTopShare = 0.01;
const comboLimit = 1.3;
const comboLevel = 45;

/// 지원 환산 κ 기본값 — 배 피해를 모두 막으면 같은 레벨 중앙 선원의 무리전 점수 × κ. 기획 판단, 조정 가능.
const defaultKappa = 0.25;

/// 지원 선원(충격 계열·배 스킬) 점수의 구성 (render-balance-crews 규칙 7).
class SupportParts {
  SupportParts(this.own, this.partnerUplift, this.shipShield);

  final double own;
  final double partnerUplift;
  final double shipShield;

  Map<String, Object> toJson() => {'own': own, 'partnerUplift': partnerUplift, 'shipShield': shipShield};
}

class CrewScore {
  CrewScore({
    required this.id,
    required this.family,
    required this.level,
    required this.a,
    required this.b,
    this.support,
  });

  final String id;
  final String family;
  final int level;

  /// 무리전·보스전(60초 환산) 피해. 지원 선원은 환산 점수.
  final double a;
  final double b;
  final SupportParts? support;
  double ratio = 1;
  bool ok = true;

  double get score => (a + b) / 2;

  Map<String, Object?> toJson() => {
    'id': id,
    'family': family,
    'level': level,
    'a': a,
    'b': b,
    'score': score,
    'ratio': ratio,
    'ok': ok,
    if (support != null) 'support': support!.toJson(),
  };
}

/// 중앙값과 벗어난 키.
typedef LevelVerdict = ({double median, Set<String> failing});

double median(Iterable<double> xs) {
  final s = [...xs]..sort();
  if (s.isEmpty) return 0;
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

LevelVerdict judgeLevel(Map<String, double> scores, {double tolerance = tolerance}) {
  final med = median(scores.values);
  return (
    median: med,
    failing: {
      for (final e in scores.entries)
        if (med > 0 && (e.value / med - 1).abs() > tolerance + 1e-12) e.key,
    },
  );
}

class ComboResult {
  ComboResult(this.crews, this.score);

  final List<String> crews;
  final double score;
  Map<String, Object> toJson() => {'crews': crews, 'score': score};
}

class BalanceReport {
  BalanceReport(this.crews, this.medians, this.combos);

  final List<CrewScore> crews;
  final Map<int, double> medians;
  final List<ComboResult> combos;
  double comboMedian = 0;
  double comboTop = 0;
  bool comboOk = true;

  bool get passed => crews.every((c) => c.ok) && comboOk;

  Map<String, Object?> toJson() => {
    'passed': passed,
    'tolerance': tolerance,
    'medians': {for (final e in medians.entries) '${e.key}': e.value},
    'crews': [for (final c in crews) c.toJson()],
    'combos': {
      'count': combos.length,
      'level': comboLevel,
      'median': comboMedian,
      'top1pct': comboTop,
      'limit': comboLimit,
      'ok': comboOk,
      'best': [for (final c in combos.take(5)) c.toJson()],
    },
  };
}

double _d(BigNum b) => b.toDouble();

/// 40명(또는 [crewIds]) × [levels] 점수표와 조합 판정 (설계서 4.8).
BalanceReport scoreCrews(
  GameTables t, {
  List<int> levels = defaultLevels,
  List<String>? crewIds,
  ArenaConfig config = const ArenaConfig(),
  double kappa = defaultKappa,
  int combos = 500,
  String? partner,
}) {
  final arena = Arena(t, config);
  final defs = [
    for (final c in t.crews.crews)
      if (crewIds == null || crewIds.contains(c.id)) c,
  ];
  final partnerId = partner ?? t.crews.crews.firstWhere((c) => c.family == 'direct').id;
  final all = <CrewScore>[];
  final medians = <int, double>{};
  for (final level in levels) {
    final rows = <CrewScore>[];
    final supportIds = <String>[];
    for (final c in defs) {
      final a = _d(arena.run(Scene.swarm, [c.id], level).damageOf(c.id));
      final b = _d(arena.run(Scene.boss, [c.id], level).damageOf(c.id)) * arena.bossScale;
      rows.add(CrewScore(id: c.id, family: c.family, level: level, a: a, b: b));
      if (_isSupport(t, c)) supportIds.add(c.id);
    }
    final medianA = median(rows.where((r) => !supportIds.contains(r.id)).map((r) => r.a));
    for (var i = 0; i < rows.length; i++) {
      if (!supportIds.contains(rows[i].id)) continue;
      rows[i] = _support(arena, rows[i], partnerId, level, kappa * medianA);
    }
    final verdict = judgeLevel({for (final r in rows) r.id: r.score});
    medians[level] = verdict.median;
    for (final r in rows) {
      r
        ..ratio = verdict.median > 0 ? r.score / verdict.median : 0
        ..ok = !verdict.failing.contains(r.id);
    }
    all.addAll(rows);
  }
  final comboResults = <ComboResult>[];
  for (final combo in sampleCombos(t, combos, seed: config.seed)) {
    final a = _d(arena.run(Scene.swarm, combo, comboLevel).totalDamage);
    final b = _d(arena.run(Scene.boss, combo, comboLevel).totalDamage) * arena.bossScale;
    comboResults.add(ComboResult(combo, (a + b) / 2));
  }
  comboResults.sort((x, y) => y.score.compareTo(x.score));
  final report = BalanceReport(all, medians, comboResults);
  if (comboResults.isNotEmpty) {
    final topN = (comboResults.length * comboTopShare).ceil();
    report
      ..comboMedian = median(comboResults.map((c) => c.score))
      ..comboTop = comboResults[topN - 1].score
      ..comboOk = report.comboTop <= report.comboMedian * comboLimit;
  }
  return report;
}

bool _isSupport(GameTables t, CrewDef c) {
  if (c.family == 'shock') return true;
  final skill = c.skill;
  return skill != null && t.skills.crewSkills.any((s) => s.id == skill && s.shape == 'ship');
}

/// 지원 환산: 자기 피해 + 파트너 증가분 + κ·(막은 배 피해 비율). 장면마다 (파트너 혼자, 함께) 두 판.
CrewScore _support(Arena arena, CrewScore solo, String partnerId, int level, double shieldUnit) {
  (double, double, double) part(Scene scene) {
    // 두 실행 모두 같은 보유 선원(파트너 + 지원) — 출전만 다르다. 보유 효과가 '파트너 증가'로 잡히지 않게.
    final owned = [partnerId, solo.id];
    final alone = arena.run(scene, [partnerId], level, owned: owned);
    final together = arena.run(scene, owned, level, owned: owned);
    final scale = scene == Scene.boss ? arena.bossScale : 1.0;
    final own = _d(together.damageOf(solo.id)) * scale;
    final uplift = (_d(together.damageOf(partnerId)) - _d(alone.damageOf(partnerId))) * scale;
    final saved = alone.shipDamage.isZero ? 0.0 : 1 - (together.shipDamage / alone.shipDamage).toDouble();
    return (own, uplift, shieldUnit * saved);
  }

  final (ownA, upA, shA) = part(Scene.swarm);
  final (ownB, upB, shB) = part(Scene.boss);
  return CrewScore(
    id: solo.id,
    family: solo.family,
    level: level,
    a: ownA + upA + shA,
    b: ownB + upB + shB,
    support: SupportParts((ownA + ownB) / 2, (upA + upB) / 2, (shA + shB) / 2),
  );
}
