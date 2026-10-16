import 'package:game_cli/src/sim/sim_cards.dart';
import 'package:game_cli/src/sim/sim_player.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 지표 하나의 판정. [value]가 null이면 시뮬 시간 안에 도달하지 못함.
class SimCheck {
  SimCheck(
    this.key,
    this.label,
    this.value,
    this.min,
    this.max, {
    required this.unit,
    this.requiredWithin,
    this.applies = true,
    this.onlyIfReached = false,
  });

  final String key;
  final String label;
  final double? value;
  final double min;
  final double max;
  final String unit;

  /// 이 지표를 판정하려면 시뮬이 이만큼은 돌아야 한다. 더 짧으면 미도달을 ‘판정 안 함’으로 본다.
  final Duration? requiredWithin;

  /// 목표가 이 접속 일정용인가 (`schedule` 키, 없으면 모든 일정).
  final bool applies;

  /// 값이 없으면(그 일이 일어나지 않았으면) 판정하지 않는다.
  final bool onlyIfReached;

  bool judged(Duration played) =>
      applies && (value != null || (!onlyIfReached && (requiredWithin == null || played >= requiredWithin!)));
  bool ok(Duration played) => !judged(played) || (value != null && value! >= min && value! <= max);

  Map<String, Object?> toJson(Duration played) => {
    'key': key,
    'value': value,
    'min': min,
    'max': max,
    'unit': unit,
    'applies': applies,
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
List<SimCheck> judge(GameTables t, List<SimResult> rs, {required String schedule}) {
  final tg = t.meta.raw.obj('sim').obj('targets');
  SimCheck c(
    String key,
    String label,
    double? Function(SimResult) f,
    String unit, {
    Duration? within,
    bool onlyIfReached = false,
  }) {
    final r = tg.obj(key);
    return SimCheck(
      key,
      label,
      median([for (final x in rs) f(x)]),
      r.number('min'),
      r.number('max'),
      unit: unit,
      requiredWithin: within ?? Duration(milliseconds: (r.number('max') * _unitMs(unit)).round()),
      applies: !r.has('schedule') || r.str('schedule') == schedule,
      onlyIfReached: onlyIfReached,
    );
  }

  final chest = t.ads.placements.firstWhere((p) => p.id == 'chest').reward;
  final adSummons = chest.number('altGems') / summonCost(t.meta, 1);
  return [
    c('firstBossFailMin', '첫 보스 실패', (r) => _min(r.firstBossFail), '분'),
    c('firstSummonMin', '첫 소환 가능', (r) => _min(r.firstSummonReady), '분'),
    c('stage10Min', '스테이지 10', (r) => _min(r.stage10), '분'),
    c('stage40DayHours', '스테이지 40 (첫날 안, 하루 일정 경과)', (r) => _hours(r.stage40), '시간'),
    c('stage40OnlineMin', '스테이지 40 (계속 접속, 20분 이상)', (r) => _min(r.stage40), '분', within: Duration.zero),
    c('wallMaxMin', '가장 긴 벽(파밍, 접속 시간)', (r) => _min(r.wallMax), '분', within: Duration.zero),
    c('offline8hUpgrades', '오프라인 8시간 = 다음 강화', (r) => r.offline8hUpgrades.toDouble(), '회', within: Duration.zero),
    c('eventGoldPct', '돌발 이벤트 골드 ÷ 처치 골드', (r) => r.eventGoldPct, '%', within: Duration.zero),
    c('challengeWinPct', '즉석 도전 성공률', (r) => r.challengeWinPct, '%', within: Duration.zero),
    c('adSummonsPerGemAd', '젬 광고 1회 = 소환', (_) => adSummons, '회', within: Duration.zero),
    c('starterPromotionMin', '옥토 첫 등급 상승(승급·점프)', (r) => _min(r.starterPromotion), '분'),
    c('firstLegendOwnedDays', '첫 전설 보유', (r) => _days(r.firstLegendOwned), '일'),
    c('firstLegendPromotedDays', '승급으로 만든 첫 전설', (r) => _days(r.firstLegendPromoted), '일'),
    c('firstMythicDays', '첫 신화', (r) => _days(r.firstMythic), '일'),
    c(
      'rebirthBeatBestMin',
      '첫 환생 뒤 이전 최고 돌파(접속 시간)',
      (r) => _min(r.rebirthBeatBest),
      '분',
      onlyIfReached: true,
    ),
    c(
      'rebirthRecoverSec',
      '환생 뒤 30% 회복(접속 시간, 가장 느린 것)',
      (r) => r.rebirthRecoverMax == null ? null : r.rebirthRecoverMax!.inMilliseconds / Duration.millisecondsPerSecond,
      '초',
      onlyIfReached: true,
    ),
  ];
}

int _unitMs(String unit) => switch (unit) {
  '분' => Duration.millisecondsPerMinute,
  '초' => Duration.millisecondsPerSecond,
  '시간' => Duration.millisecondsPerHour,
  '일' => Duration.millisecondsPerDay,
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
    final verdict = !c.applies
        ? '다른 일정 기준'
        : !c.judged(played)
        ? '판정 안 함(시뮬 짧음)'
        : (c.ok(played) ? 'OK' : '벗어남');
    b.writeln('| ${c.label} | ${_fmt(c.value, ' ${c.unit}')} | ${_fmt(c.min)}~${_fmt(c.max)} | $verdict |');
  }
  double? m(double? Function(SimResult) f) => median([for (final r in rs) f(r)]);
  b
    ..writeln()
    ..writeln('| 참고 | 값 |')
    ..writeln('| --- | --- |')
    ..writeln(
      '| 환생 횟수 · 첫 환생(경과·스테이지) · 지도 조각 | ${_fmt(m((r) => r.rebirths.toDouble()))} · '
      '${_fmt(m((r) => _hours(r.firstRebirth)), '시간')}·${_fmt(m((r) => r.firstRebirthStage?.toDouble()))} · '
      '${_fmt(m((r) => r.mapPieces.toDouble()))} |',
    )
    ..writeln(
      '| 환생 스테이지(최대) · 회복 ÷ 직전 회차 같은 스테이지 시간(최대) | '
      '${_fmt(m((r) => r.rebirthStages.isEmpty ? null : r.rebirthStages.reduce((a, b) => a > b ? a : b).toDouble()))} · '
      '${_fmt(m((r) => r.rebirthRecoverRatioMax))} |',
    )
    ..writeln(
      '| 환생 뒤 회복 중 연속 보스 간격(중앙값 · 최소) | '
      '${_fmt(m((r) => r.recoverBossGaps.isEmpty ? null : median(r.recoverBossGaps)), '초')} · '
      '${_fmt(m((r) => r.recoverBossGaps.isEmpty ? null : r.recoverBossGaps.reduce((a, b) => a < b ? a : b)), '초')} |',
    )
    ..writeln(
      '| 환생 미리보기 추정 ÷ 실제 이전 최고 돌파 | '
      '${_fmt(m((r) => r.rebirthForecastMin == null || r.rebirthBeatBest == null ? null : r.rebirthForecastMin! / _min(r.rebirthBeatBest)!))} |',
    )
    ..writeln('| 첫 보스 실패 스테이지 | ${_fmt(m((r) => r.firstBossFailStage?.toDouble()))} |')
    ..writeln('| 첫 등급 상승(아무 선원, 카드 점프 포함) | ${_fmt(m((r) => _min(r.firstRarityUp)), '분')} |')
    ..writeln('| 최고 스테이지 | ${_fmt(m((r) => r.bestStage.toDouble()))} |')
    ..writeln(
      '| 한 파 소요(처음 10분 / 전체) | ${_fmt(m((r) => r.waveSecFirst10Min), '초')} / ${_fmt(m((r) => r.waveSecAll), '초')} |',
    )
    ..writeln(
      '| 오프라인 추정 ÷ 실제 초당 골드(마지막 10분) | '
      '${_fmt(m((r) => r.goldPerSecActual.isZero ? null : (r.goldPerSecEstimated / r.goldPerSecActual).toDouble()))} |',
    )
    ..writeln(
      '| 배 외형 단계(부위별 최고, 첫날 / 첫 주) | '
      '${[for (final p in t.shipParts.parts) '${p.id} ${_fmt(m((r) => (r.lookDay1[p.id] ?? 0).toDouble()))}/${_fmt(m((r) => (r.lookWeek1[p.id] ?? 0).toDouble()))}'].join(' · ')} |',
    )
    ..writeln(
      '| 부위 최고 레벨(첫날 / 첫 주) | '
      '${[for (final p in t.shipParts.parts) '${p.id} ${_fmt(m((r) => (r.levelDay1[p.id] ?? 0).toDouble()))}/${_fmt(m((r) => (r.levelWeek1[p.id] ?? 0).toDouble()))}'].join(' · ')} |',
    )
    ..writeln('| 함포 지원 광고(보스 실패 뒤) | ${_fmt(m((r) => r.bossAds.toDouble()))} |')
    ..writeln('| 강화·소환 횟수 | ${_fmt(m((r) => r.upgrades.toDouble()))} · ${_fmt(m((r) => r.summons.toDouble()))} |');
  _cardsByRun(b, t, rs);
  return b.toString();
}

/// 회차별 카드 수입 표 (중앙값, 보스 카드는 기댓값). 앞 [shown]회차는 하나씩, 나머지는 합쳐서.
void _cardsByRun(StringBuffer b, GameTables t, List<SimResult> rs, {int shown = 6}) {
  final rates = t.rarities.bossDropRates;
  final ids = rates.keys.toList();
  String pct(double v) => '${(v * 100).toStringAsFixed(v < 0.1 ? 1 : 0)}%';
  b
    ..writeln()
    ..writeln(
      '보스 카드(기댓값) 등급 구성: ${[for (final id in ids) '$id ${pct(rates[id]!)}'].join(' · ')} — '
      '장수는 스테이지 1~${t.growth.bossCards.earlyStageMax} ${t.growth.bossCards.early}장, '
      '이후 ${t.growth.bossCards.base} + floor(스테이지/${t.growth.bossCards.stagesPerExtra})',
    )
    ..writeln()
    ..writeln('| 회차 | 새 보스 · 반복 보스 | 새 보스 카드 (${ids.join('/')}) | 반복 보스 카드 (${ids.join('/')}) | 시작 카드 | 소환 |')
    ..writeln('| --- | --- | --- | --- | --- | --- |');
  final runs = rs.map((r) => r.cardsByRun.length).fold(0, (a, n) => n > a ? n : a);
  for (var i = 0; i < runs && i <= shown; i++) {
    final last = i == shown;
    // 플레이어마다 이 구간의 회차들을 합친다. 그 회차가 없으면 null(중앙값에서 미도달).
    List<RunCards>? pick(SimResult r) =>
        r.cardsByRun.length <= i ? null : (last ? r.cardsByRun.sublist(i) : [r.cardsByRun[i]]);
    String med(double Function(List<RunCards>) f) =>
        _fmt(median([for (final r in rs) pick(r) == null ? null : f(pick(r)!)]));
    double total(List<RunCards> xs, num Function(RunCards) f) => xs.fold(0, (a, x) => a + f(x));
    String byRarity(Map<String, double> Function(RunCards) f) => [
      for (final id in ids) med((xs) => total(xs, (x) => f(x)[id] ?? 0)),
    ].join(' / ');
    b.writeln(
      '| ${last ? '${i + 1}회차~' : '${i + 1}회차'} '
      '| ${med((xs) => total(xs, (x) => x.newBosses))} · ${med((xs) => total(xs, (x) => x.repeatBosses))} '
      '| ${byRarity((x) => x.newByRarity)} | ${byRarity((x) => x.repeatByRarity)} '
      '| ${med((xs) => total(xs, (x) => x.starterCards))} | ${med((xs) => total(xs, (x) => x.summons))} |',
    );
  }
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
          'firstRarityUpMin': _min(r.firstRarityUp),
          'starterPromotionMin': _min(r.starterPromotion),
          'firstLegendOwnedDays': _days(r.firstLegendOwned),
          'firstLegendPromotedDays': _days(r.firstLegendPromoted),
          'firstMythicDays': _days(r.firstMythic),
          'upgrades': r.upgrades,
          'summons': r.summons,
          'gold': r.gold.toJson(),
          'gems': r.gems,
          'cardsByRun': [for (final c in r.cardsByRun) c.toJson()],
        },
    ],
  };
}
