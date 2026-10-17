import 'dart:convert';
import 'dart:ui';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

final tables = GameTables.load();

/// 배 순항(waves.top.cruise)을 뺀 표 — 배가 가운데 고정이라고 보고 다른 연출을 재는 시험용(S5 still_ship과 같은 꼴).
final stillTables = GameTables.load(() {
  final raw = Map<String, String>.of(rawTables);
  final w = jsonDecode(raw['waves']!) as Map<String, dynamic>;
  _noDodge((w['top'] as Map<String, dynamic>)..remove('cruise'));
  return raw..['waves'] = jsonEncode(w);
}());

/// 대군 습격(waves.top.horde — 스테이지 첫 파가 사방에서 큰 무리)을 뺀 표: 첫 파 타이밍에 맞춘 연출 시험용(S2 2026-10-18).
final noHordeTables = GameTables.load(() {
  final raw = Map<String, String>.of(rawTables);
  final w = jsonDecode(raw['waves']!) as Map<String, dynamic>;
  _noDodge((w['top'] as Map<String, dynamic>)..remove('horde'));
  return raw..['waves'] = jsonEncode(w);
}());

/// 보스전 회피(bossDuel.dodge·bossDodge — 배가 예고 때 옆으로 비킴)도 뺀다: 배 자리를 고정으로 보는 연출 시험용(S5 still_ship과 같음).
void _noDodge(Map<String, dynamic> top) {
  top.remove('bossDodge');
  (top['bossDuel'] as Map<String, dynamic>?)?.remove('dodge');
}

double get tickMs => tables.waves.tickMs.toDouble();

/// 테스트용 기록 한 틱. [enemies]는 (id, x) 목록, y는 100 고정.
RecordedTick tickOf(
  int i, {
  List<(int, double)> enemies = const [],
  List<GameEvent> events = const [],
  int hitStop = 0,
  int speed = 1,
}) => RecordedTick(
  BattleView(
    tick: i,
    shipHp: BigNum.from(60),
    shipHpMax: BigNum.from(60),
    enemies: [for (final (id, x) in enemies) EnemyView(id: id, kind: 'crab', x: x, y: 100, hpRatio: 1)],
    hitStopTicks: hitStop,
    speed: speed,
  ),
  events,
);

/// 적 하나가 매 틱 2px씩 다가오는 기록.
List<RecordedTick> marching(int n, {Map<int, List<GameEvent>> events = const {}}) => [
  for (var i = 0; i < n; i++) tickOf(i, enemies: [(1, 300 - 2.0 * i)], events: events[i] ?? const []),
];

/// 탑다운 그리기로 한 장(T4-3 — 옆모습 ScenePainter.paint 대신): 기본 상자 kLogicalWidth × kLogicalHeight, dpr 1.
/// 선원 줄·궁극기 등 HUD 자리는 BattleFrame.standard와 같다.
void paintTopStd(ScenePainter painter, Canvas canvas) =>
    painter.paintTop(canvas, topFrameFor(const Size(kLogicalWidth, kLogicalHeight), 1));
