import 'dart:convert';
import 'dart:io';

import 'package:game_cli/src/sim/sim_player.dart';
import 'package:game_core/game_core.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 장기 실행 안정성(S1 2026-10-18): 가상 시계로 오래 돌려도 예외·BigNum 넘침·NaN·무한 루프가 없고, 세이브가 무한히 크지 않고,
/// 오프라인 복귀·환생 반복이 맞는지. 시뮬 두 개(연속·하루 일정)는 무거워 `SOAK=1`일 때만 — 24시간 연속·30일 일정
/// (`SOAK=1 dart test test/soak`, 수십 분). 오프라인·환생은 가벼워 늘 돈다.
void main() {
  final t = GameTables.load();
  final long = Platform.environment['SOAK'] == '1';
  final skip = long ? null : 'SOAK=1일 때만(무거움)';
  final start = DateTime.utc(2026, 11);

  /// 상태 하나의 불변식: JSON 왕복이 같고, 숫자가 유한하고, 목록이 상한 안.
  void invariants(GameState s, String at) {
    final text = SaveCodec.encode(s);
    final back = SaveCodec.decode(text);
    expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()), reason: '$at 세이브 왕복');
    void finite(BigNum n, String what) {
      expect(n.mantissa.isFinite, isTrue, reason: '$at $what mantissa ${n.mantissa}');
    }

    finite(s.wallet.gold, 'gold');
    expect(s.progress.fever.isFinite, isTrue, reason: '$at fever');
    expect(s.wallet.gems, greaterThanOrEqualTo(0), reason: '$at gems');
    final b = s.battle;
    if (b != null) {
      finite(b.shipHp, 'shipHp');
      finite(b.shipHpMax, 'shipHpMax');
      for (final e in b.enemies) {
        expect(e.x.isFinite && e.y.isFinite && e.hpRatio.isFinite, isTrue, reason: '$at enemy ${e.kind}');
      }
      expect(b.enemies.length, lessThan(2000), reason: '$at 적 수 폭주');
    }
    // 목록 상한: 영수증·도감·업적·칭호·선원은 표나 상수로 막혀 있어야 한다.
    expect(s.purchaseTokens.length, lessThanOrEqualTo(purchaseTokenKeep), reason: at);
    expect(
      s.progress.dex.kills.length,
      lessThanOrEqualTo(t.regions.enemies.length + t.regions.bosses.length),
      reason: at,
    );
    expect(s.achievements.claimed.length, lessThanOrEqualTo(t.achievements.achievements.length), reason: at);
    expect(s.crews.length, lessThanOrEqualTo(t.crews.crews.length), reason: at);
    expect(text.length, lessThan(64 * 1024), reason: '$at 세이브 ${text.length}B');
  }

  test(
    '연속 플레이 ${long ? 24 : 1}시간(자동 강화·소환·보스·피버·환생 상점): 구간마다 불변식',
    () {
      final p = SimPlayer(t, seed: 11);
      final hours = long ? 24 : 1;
      for (var h = 1; h <= hours; h++) {
        p.run(Duration(hours: h), SimSchedule(online: Duration(hours: hours)));
        invariants(p.engine.state, '${h}h');
      }
      expect(p.engine.state.progress.bestStage, greaterThan(10));
    },
    timeout: const Timeout(Duration(hours: 2)),
    skip: skip,
  );

  test(
    '하루 일정 ${long ? 30 : 3}일(20분 접속 → 8시간 → 20분 → 15시간 20분): 날마다 불변식·세이브 크기',
    () {
      final p = SimPlayer(t, seed: 12);
      final days = long ? 30 : 3;
      for (var d = 1; d <= days; d++) {
        p.run(Duration(days: d), SimSchedule.daily);
        invariants(p.engine.state, 'day $d');
      }
    },
    timeout: const Timeout(Duration(hours: 2)),
    skip: skip,
  );

  test('오프라인 복귀: 8시간·30일 — 상한(maxSec)까지만, 유한한 골드', () {
    final s = GameState.fromJson(
      jsonDecode(File('../../fixtures/states/stage37_midgame.json').readAsStringSync()) as Map<String, dynamic>,
    ).copyWith(clearTutorial: true, savedAt: start);
    BigNum claim(Duration away) {
      final clock = ManualClock(start.add(away));
      final e = CoreEngine(tables: t, clock: clock, initial: s)
        ..tick()
        ..enqueue(const ClaimOffline())
        ..tick();
      invariants(e.state, 'offline $away');
      return e.state.lastOfflineGold ?? BigNum.zero;
    }

    final eight = claim(const Duration(hours: 8));
    final month = claim(const Duration(days: 30));
    expect(eight.mantissa.isFinite && month.mantissa.isFinite, isTrue);
    expect(month <= eight.times(1.0001), isTrue, reason: '30일도 상한(8시간)까지만: $month vs $eight');
  });

  test('환생 50회 반복: 매번 최소 스테이지까지 갔다 환생 — 횟수·칭호·지도 조각이 맞고 불변식', () {
    final minStage = t.meta.raw.obj('rebirth').integer('minStage');
    final e = CoreEngine(
      tables: t,
      clock: ManualClock(start),
      initial: GameState.newGame(playerId: 'r', seed: 3, now: start).copyWith(clearTutorial: true),
    )..tick();
    for (var i = 1; i <= 50; i++) {
      e
        ..enqueue(OpJumpStage(minStage + i))
        ..tick()
        ..enqueue(const Rebirth())
        ..advance(3);
      expect(e.state.progress.rebirths, i, reason: '환생 $i');
      if (i % 10 == 0) invariants(e.state, 'rebirth $i');
    }
    expect(e.state.progress.mapPiecesEarned, greaterThan(0));
  });
}
