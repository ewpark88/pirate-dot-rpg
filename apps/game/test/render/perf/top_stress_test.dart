// 탑다운 부하(S1: 화면 동시 적 수십~100, 렌더는 100~150마리에서 60fps): 150마리가 사방에서 배로 다가오며 매 틱 여러 발 발사.
// 숫자는 출력만, 상한은 느슨하게(회귀 방지): 프레임당 그리기 호출 수.
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/demo/stress_recording.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/paint/scene_painter.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/top_frame.dart';

import '../helpers.dart';
import 'counting_canvas.dart';

Future<void> _measure(
  WidgetTester tester,
  String name,
  List<RecordedTick> rec, {
  double maxCalls = 900,
  double coverAt = -1,
}) async {
  final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
  const box = Size(384, 684);
  final scene = BattleScene(tables, rec)..layout = battleFrameFor(box, 2.8125);
  final painter = ScenePainter(scene)..sprites = bank;
  var frame = topFrameFor(box, 2.8125);
  final warm = Canvas(PictureRecorder());
  for (var i = 0; i < 120; i++) {
    scene.update(kFrameMs);
    painter.paintTop(warm, frame);
  }
  // 시트가 열려 전장이 가려진 상태(상자 높이 절반) — 렌더가 가벼운 연출로 바뀐다.
  if (coverAt > 0) frame = topFrameFor(Size(box.width, box.height * coverAt), 2.8125);
  var calls = 0;
  final names = <String, int>{};
  final sw = Stopwatch();
  final per = <double>[];
  const frames = 300;
  for (var i = 0; i < frames; i++) {
    scene.update(kFrameMs);
    final c = CountingCanvas();
    painter.paintTop(c, frame);
    calls += c.calls;
    c.byName.forEach((k, v) => names[k] = (names[k] ?? 0) + v);
    final one = Stopwatch()..start();
    sw.start();
    painter.paintTop(warm, frame);
    sw.stop();
    per.add(one.elapsedMicroseconds / 1000);
  }
  // 측정값을 남긴다(부하 전후 표).
  // ignore: avoid_print
  print(
    '[$name] 그리기 ${(calls / frames).toStringAsFixed(1)}/프레임, 기록 평균 ${(sw.elapsedMicroseconds / frames / 1000).toStringAsFixed(2)}ms · p95 ${(per..sort())[(per.length * 0.95).floor()].toStringAsFixed(2)}ms (디버그 JIT, 상대 비교용)',
  );
  // 그리기 종류별 수를 남긴다(어디를 줄일지).
  // ignore: avoid_print
  print(
    '  ${names.map((k, v) => MapEntry(k.replaceAll('Symbol("', '').replaceAll('")', ''), (v / frames).toStringAsFixed(1)))}',
  );
  expect(calls / frames, lessThan(maxCalls));
}

void main() {
  testWidgets('탑다운 부하 150마리(대부분 화면 안)', (tester) => _measure(tester, 'top stress 150', stressRecording()));
  testWidgets(
    '탑다운 부하 150마리(사방 넓게 — 화면 밖 많음)',
    (tester) => _measure(tester, 'top stress 150 wide', stressRecording(spread: 300)),
  );
  // 피버 무리(S2 fever-swarm: 피버 ×2.5, 화면 최대 200마리) + 손맛 v4·피버 v2 파편(피버면 처치 조각 14개).
  testWidgets(
    '탑다운 피버 200마리',
    (tester) => _measure(tester, 'top fever 200', _worst(count: 200), maxCalls: 1600),
  );
  // 최악 장면(S1 성능 점검): 150마리 + 피버 질주·꼬리·범위 임팩트·보스 패턴·낙뢰·보호막·적 탄·돌파 사격을 한꺼번에.
  testWidgets('탑다운 최악 장면(새 효과 전부)', (tester) => _measure(tester, 'top worst', _worst(), maxCalls: 1400));
  testWidgets(
    '탑다운 최악 장면 + 시트 열림(가벼운 연출)',
    (tester) => _measure(tester, 'top worst covered', _worst(), coverAt: 0.5),
  );
}

List<RecordedTick> _worst({int count = 150}) {
  final base = stressRecording(count: count);
  return [
    for (var i = 0; i < base.length; i++)
      () {
        final f = base[i].frame;
        final frame = BattleView.fromJson({
          ...f.toJson(),
          'feverTicksLeft': 500,
          'shipShield': 0.7,
          'fastSail': {'from': 31, 'to': 43, 'combo': i, 'phase': 'rush', 'speed': 8},
          'fleet': [
            // 사용자 버그 '모두 신화'(선원 6명 신화)에서 버벅임 — 전원 신화.
            for (final id in const ['octo', 'pang', 'sword', 'turtle', 'pelly', 'gull'])
              {'crewId': id, 'cooldown': 0, 'skillCooldown': 0, 'rarity': 4},
          ],
        });
        final e = f.enemies[i % f.enemies.length];
        return RecordedTick(frame, [
          ...base[i].events,
          AoeDamageSum(f.tick, total: BigNum.from(999), x: e.x, y: e.y),
          if (i % 3 == 0) EnemyFired(f.tick, enemyId: e.id, fromX: e.x, fromY: e.y, flightTicks: 20, kind: 'ember'),
          if (i % 4 == 0)
            AttackFired(
              f.tick,
              crewId: 'pelly',
              family: 'air',
              targetIds: [e.id],
              x: e.x,
              y: e.y,
              kind: 'lightning',
              flightTicks: 8,
            ),
          if (i % 5 == 0)
            BreakthroughStrike(
              f.tick,
              stage: 31,
              bossId: 'enemy_ship',
              x: 135,
              y: 150,
              combo: i,
              phase: 'rush',
              speed: 8,
            ),
          if (i % 40 == 0)
            BossPatternShown(
              f.tick,
              enemyId: e.id,
              kind: 'blast',
              phase: 'warn',
              warnTicks: 12,
              x: 135,
              y: 150,
              angle: 1.57,
              count: 5,
              radius: 56,
            ),
        ]);
      }(),
  ];
}
