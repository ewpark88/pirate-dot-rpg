import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// 시나리오 하나의 결과.
class ScenarioResult {
  ScenarioResult(this.name, {this.skipReason, this.failures = const []});

  final String name;
  final String? skipReason;
  final List<String> failures;

  bool get passed => skipReason == null && failures.isEmpty;
}

/// 시나리오 YAML (docs/GAME_DESIGN.md 7.1). 수용 기준 하나 = 파일 하나.
///
/// ```yaml
/// name: 보스 시간 초과 시 파밍 모드로 전환된다
/// seed: 42
/// state: fixtures/states/boss_fight.json   # 저장소 루트 기준
/// skip: "M1 전투 규칙 구현 전"              # 있으면 건너뜀
/// steps:
///   - advance: 31s        # 또는 620t (틱)
///   - expect: { bossActive: false, farming: true, stage: 5 }
///   - input: challengeBoss               # 또는 { type: upgradePart, part: cannon }
/// ```
ScenarioResult runScenario(File file, Directory root, {GameTables? tables}) {
  final y = loadYaml(file.readAsStringSync()) as YamlMap;
  final name = y['name'] as String? ?? p.basename(file.path);
  if (y['skip'] != null) return ScenarioResult(name, skipReason: '${y['skip']}');

  final statePath = (y['state'] ?? y['save']) as String;
  final raw = jsonDecode(File(p.join(root.path, statePath)).readAsStringSync()) as Json;
  var initial = GameState.fromJson(SaveCodec.migrate(raw));
  if (y['seed'] != null) initial = initial.copyWith(rngSeed: y['seed'] as int);

  final t = tables ?? GameTables.load();
  final engine = CoreEngine(tables: t, clock: ManualClock(initial.savedAt), initial: initial);
  final tickMs = engine.tickLength.inMilliseconds;
  final failures = <String>[];

  final steps = (y['steps'] as YamlList).cast<YamlMap>();
  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    final where = '${p.basename(file.path)} steps[$i]';
    if (step['advance'] != null) {
      engine.advance(_ticks('${step['advance']}', tickMs));
    } else if (step['input'] != null) {
      final input = step['input'];
      engine
        ..enqueue(Command.fromJson(input is String ? {'type': input} : _plain(input)! as Json))
        ..tick();
    } else if (step['expect'] != null) {
      final actual = observe(engine.state, t);
      for (final e in (step['expect'] as YamlMap).entries) {
        final key = '${e.key}';
        if (!actual.containsKey(key)) {
          failures.add('$where: 모르는 기대 키 $key (가능: ${actual.keys.join(', ')})');
        } else if ('${actual[key]}' != '${e.value}') {
          failures.add('$where: $key 기대 ${e.value}, 실제 ${actual[key]}');
        }
      }
    } else {
      failures.add('$where: advance / input / expect 중 하나여야 합니다');
    }
  }
  return ScenarioResult(name, failures: failures);
}

/// expect에서 쓸 수 있는 관찰값. 새 키가 필요하면 여기에 추가한다. [t]가 있으면 탑다운 키도.
Map<String, Object?> observe(GameState s, [GameTables? t]) => {
  'stage': s.progress.stage,
  'wave': s.progress.wave,
  'bestStage': s.progress.bestStage,
  'farming': s.progress.farming,
  'rebirths': s.progress.rebirths,
  'gems': s.wallet.gems,
  'gold': s.wallet.gold.toString(),
  'mapPieces': s.wallet.mapPieces,
  'bossActive': s.battle?.bossActive,
  'enemies': s.battle?.enemies.length,
  'crews': s.crews.length,
  'operator': s.operator,
  // 이번 복귀에 오프라인 보상을 받았는가 (ClaimOffline 뒤 lastOfflineGold).
  'offlineRewarded': s.lastOfflineGold != null,
  // 배 외형 단계 (ship_parts.json visualStages). 부위마다 키 하나 — 예: { look.cannon: 2 }
  for (final e in (s.battle?.shipLook ?? const <String, int>{}).entries) 'look.${e.key}': e.value,
  // 탑다운(탑다운 전환 T1): 전장 방식, 적이 있는 사분면 수(배 중심 기준), 보스가 standoff 원에 섰는가.
  'mode': s.battle?.mode,
  if (t != null) ...topObservations(s, t),
};

/// 탑다운 관찰값. 옆모습이면 비어 있다.
Map<String, Object?> topObservations(GameState s, GameTables t) {
  final b = s.battle;
  if (b == null || b.mode != 'top') return const {};
  final top = t.waves.top;
  final cx = b.shipX ?? top.shipX;
  final cy = b.shipY ?? top.shipY;
  double dist(EnemyView e) => math.sqrt(math.pow(e.x - cx, 2) + math.pow(e.y - cy, 2));
  final boss = b.enemies.where((e) => e.boss).firstOrNull;
  return {
    'quadrants': {for (final e in b.enemies.where((e) => !e.boss)) (e.x >= cx ? 1 : 0) + (e.y >= cy ? 2 : 0)}.length,
    // 원 안으로 들어오지 않고, 밀려도 standoff + 20 안(옆모습 시나리오처럼 숫자 대신 규칙으로 — 표 값이 바뀌어도 그대로).
    'bossAtStandoff': boss != null && dist(boss) >= top.bossStandoff - 1e-6 && dist(boss) <= top.bossStandoff + 20,
  };
}

int _ticks(String text, int tickMs) {
  final m = RegExp(r'^(\d+(?:\.\d+)?)\s*(s|t|ms)$').firstMatch(text.trim());
  if (m == null) throw FormatException('advance 형식은 40s / 800t / 500ms', text);
  final v = double.parse(m.group(1)!);
  return switch (m.group(2)) {
    's' => (v * 1000 / tickMs).round(),
    'ms' => (v / tickMs).round(),
    _ => v.round(),
  };
}

Object? _plain(Object? y) => switch (y) {
  YamlMap() => {for (final e in y.entries) '${e.key}': _plain(e.value)},
  YamlList() => [for (final v in y) _plain(v)],
  _ => y,
};
