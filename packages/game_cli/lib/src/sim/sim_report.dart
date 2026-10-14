import 'package:game_cli/src/sim/sim_player.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 지표 하나의 판정. [value]가 null이면 시뮬 시간 안에 도달하지 못함.
class SimCheck {
  SimCheck(this.key, this.label, this.value, this.min, this.max, {required this.unit, this.requiredWithin});

  final String key;
  final String label;
  final double? value;
  final double min;
  final double max;
  final String unit;

  /// 이 지표를 판정하려면 시뮬이 이만큼은 돌아야 한다. 더 짧으면 미도달을 ‘판정 안 함’으로 본다.
  final Duration? requiredWithin;

  bool judged(Duration played) => value != null || requiredWithin == null || played >= requiredWithin!;
  bool ok(Duration played) => !judged(played) || (value != null && value! >= min && value! <= max);

  Map<String, Object?> toJson(Duration played) => {
    'key': key,
    'value': value,
    'min': min,
    'max': max,
    'unit': unit,
    'judged': judged(played),
    'ok': ok(played),
  };
}

double? _min(Duration? d) => d == null ? null : d.inMilliseconds / Duration.millisecondsPerMinute;
double? _hours(Duration? d) => d == null ? null : d.inMilliseconds / Duration.millisecondsPerHour;
double? _days(Duration? d) => d == null ? null : d.inMilliseconds / Duration.millisecondsPerDay;

/// 여러 명 결과의 중앙값 (null은 ‘미도달’로 가장 큰 값 취급).
double? median(List<double?> xs) {
  final sorted = [...xs]..sort((a, b) => (a ?? double.infinity).compareTo(b ?? double.infinity));
  return sorted[sorted.length ~/ 2];
}

/// 설계서 7.2 목표 판정 (범위는 meta.json sim.targets).
List<SimCheck> judge(GameTables t, List<SimResult> rs) {
  final tg = t.meta.raw.obj('sim').obj('targets');
  SimCheck c(String key, String label, double? Function(SimResult) f, String unit, {Duration? within}) {
    final r = tg.obj(key);
    return SimCheck(
      key,
      label,
      median([for (final x in rs) f(x)]),
      r.number('min'),
      r.number('max'),
      unit: unit,
      requiredWithin: within ?? Duration(milliseconds: (r.number('max') * _unitMs(unit)).round()),
    );
  }

  final chest = t.ads.placements.firstWhere((p) => p.id == 'chest').reward;
  final adSummons = chest.number('altGems') / summonCost(t.meta, 1);
  return [
    c('firstBossFailMin', '첫 보스 실패', (r) => _min(r.firstBossFail), '분'),
    c('firstSummonMin', '첫 소환 가능', (r) => _min(r.firstSummonReady), '분'),
    c('stage10Min', '스테이지 10', (r) => _min(r.stage10), '분'),
    c('stage40Hours', '스테이지 40 (환생 해금)', (r) => _hours(r.stage40), '시간'),
    c('wallMaxMin', '가장 긴 벽(파밍) 구간', (r) => _min(r.wallMax), '분', within: Duration.zero),
    c('offline8hUpgrades', '오프라인 8시간 = 다음 강화', (r) => r.offline8hUpgrades.toDouble(), '회', within: Duration.zero),
    c('adSummonsPerGemAd', '젬 광고 1회 = 소환', (_) => adSummons, '회', within: Duration.zero),
  ];
}

int _unitMs(String unit) => switch (unit) {
  '분' => Duration.millisecondsPerMinute,
  '시간' => Duration.millisecondsPerHour,
  _ => 0,
};

String _fmt(double? v, [String unit = '']) =>
    v == null ? '미도달' : '${v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}$unit';

/// 사람이 읽는 표.
String formatReport(GameTables t, List<SimResult> rs, List<SimCheck> checks) {
  final played = rs.first.played;
  final b = StringBuffer()
    ..writeln('# 밸런스 시뮬 — 가상 플레이어 ${rs.length}명 × ${_fmt(_hours(played))}시간 (중앙값)')
    ..writeln()
    ..writeln('| 지표 | 값 | 목표 | 판정 |')
    ..writeln('| --- | --- | --- | --- |');
  for (final c in checks) {
    final verdict = !c.judged(played) ? '판정 안 함(시뮬 짧음)' : (c.ok(played) ? 'OK' : '벗어남');
    b.writeln('| ${c.label} | ${_fmt(c.value, ' ${c.unit}')} | ${_fmt(c.min)}~${_fmt(c.max)} | $verdict |');
  }
  double? m(double? Function(SimResult) f) => median([for (final r in rs) f(r)]);
  b
    ..writeln()
    ..writeln('| 참고 | 값 |')
    ..writeln('| --- | --- |')
    ..writeln('| 최고 스테이지 | ${_fmt(m((r) => r.bestStage.toDouble()))} |')
    ..writeln(
      '| 한 파 소요(처음 10분 / 전체) | ${_fmt(m((r) => r.waveSecFirst10Min), '초')} / ${_fmt(m((r) => r.waveSecAll), '초')} |',
    )
    ..writeln('| 첫 승급 | ${_fmt(m((r) => _min(r.firstPromotion)), '분')} |')
    ..writeln(
      '| 첫 전설 보유 / 승급으로 전설 | ${_fmt(m((r) => _days(r.firstLegendOwned)), '일')} / ${_fmt(m((r) => _days(r.firstLegendPromoted)), '일')} |',
    )
    ..writeln('| 첫 신화 | ${_fmt(m((r) => _days(r.firstMythic)), '일')} |')
    ..writeln('| 강화·소환 횟수 | ${_fmt(m((r) => r.upgrades.toDouble()))} · ${_fmt(m((r) => r.summons.toDouble()))} |');
  return b.toString();
}

Map<String, Object?> reportJson(List<SimResult> rs, List<SimCheck> checks) {
  final played = rs.first.played;
  return {
    'players': rs.length,
    'hours': _hours(played),
    'checks': [for (final c in checks) c.toJson(played)],
    'results': [
      for (final r in rs)
        {
          'seed': r.seed,
          'bestStage': r.bestStage,
          'firstBossFailMin': _min(r.firstBossFail),
          'firstSummonMin': _min(r.firstSummonReady),
          'stage10Min': _min(r.stage10),
          'stage40Hours': _hours(r.stage40),
          'wallMaxMin': _min(r.wallMax),
          'offline8hUpgrades': r.offline8hUpgrades,
          'waveSecFirst10Min': r.waveSecFirst10Min,
          'waveSecAll': r.waveSecAll,
          'firstPromotionMin': _min(r.firstPromotion),
          'upgrades': r.upgrades,
          'summons': r.summons,
          'gold': r.gold.toJson(),
          'gems': r.gems,
        },
    ],
  };
}
