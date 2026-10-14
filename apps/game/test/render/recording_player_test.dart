import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';

import 'helpers.dart';

class _Log implements ReplayListener {
  final ahead = <(int, double)>[];
  final now = <(int, double)>[];
  RecordingPlayer? player;
  int loops = 0;

  @override
  void onAhead(RecordedTick tick, int index) => ahead.add((index, player!.position));

  @override
  void onNow(RecordedTick tick, int index) => now.add((index, player!.position));

  @override
  void onLoop() => loops++;
}

RecordingPlayer _playerOf(List<RecordedTick> ticks, {_Log? log, bool loop = false}) {
  final p = RecordingPlayer(ticks, tickMs: tickMs, lookaheadTicks: 2, loop: loop, listener: log);
  log?.player = p;
  return p;
}

void main() {
  group('수용 기준 1: 두 틱 사이 보간', () {
    test('x 300→298의 중간이면 299', () {
      final p = _playerOf([
        tickOf(0, enemies: [(1, 300)]),
        tickOf(1, enemies: [(1, 298)]),
      ])..advance(tickMs / 2);
      expect(p.poseOf(1)!.x, closeTo(299, 1e-9));
    });

    test('다음 틱에 없는 적은 마지막 위치에 머문다', () {
      final p = _playerOf([
        tickOf(0, enemies: [(1, 300), (2, 250)]),
        tickOf(1, enemies: [(1, 298)]),
      ])..advance(tickMs / 2);
      expect(p.poseOf(2)!.x, 250);
    });

    test('배속 2면 틱이 두 배 빨리 지나간다', () {
      final p = _playerOf([
        tickOf(0, enemies: [(1, 300)], speed: 2),
        tickOf(1, enemies: [(1, 298)], speed: 2),
        tickOf(2, enemies: [(1, 296)], speed: 2),
      ])..advance(tickMs / 2);
      expect(p.position, closeTo(1, 1e-9));
    });
  });

  group('수용 기준 2: lookahead 2틱', () {
    test('틱 t의 이벤트는 표시 시각 t-2에 앞서 알리고 t에 지금으로 알린다', () {
      final log = _Log();
      final p = _playerOf(marching(8), log: log)..advance(0);
      expect(log.ahead.map((e) => e.$1), [0, 1, 2]);
      p.advance(tickMs * 2);
      expect(log.ahead.last, (4, 2.0));
      p.advance(tickMs * 2);
      expect(log.now.where((e) => e.$1 == 4).single.$2, 4.0);
    });

    test('motionBetween은 멈춘 구간을 빼고 센다', () {
      final p = _playerOf([
        tickOf(0, enemies: [(1, 300)]),
        tickOf(1, enemies: [(1, 298)]),
        tickOf(1, enemies: [(1, 298)], hitStop: 1),
        tickOf(2, enemies: [(1, 296)]),
      ]);
      expect(p.motionBetween(0, 3), 2);
    });
  });

  group('수용 기준 3: 히트스톱', () {
    final ticks = [
      tickOf(0, enemies: [(1, 300)]),
      tickOf(1, enemies: [(1, 298)]),
      tickOf(1, enemies: [(1, 298)], hitStop: 2),
      tickOf(1, enemies: [(1, 298)], hitStop: 1),
      tickOf(2, enemies: [(1, 296)]),
    ];

    test('hitStopTicks>0 프레임으로 가는 구간은 멈춤이고 위치가 그대로다', () {
      final p = _playerOf(ticks)..advance(tickMs * 1.5);
      expect(p.inHitStop, isTrue);
      final x = p.poseOf(1)!.x;
      p.advance(tickMs);
      expect(p.inHitStop, isTrue);
      expect(p.poseOf(1)!.x, x);
      p.advance(tickMs);
      expect(p.inHitStop, isFalse);
      expect(p.poseOf(1)!.x, lessThan(x));
    });
  });

  test('반복 재생: 끝에서 처음으로 돌아가며 onLoop', () {
    final log = _Log();
    final p = _playerOf(marching(4), log: log, loop: true)..advance(tickMs * 4.5);
    expect(log.loops, 1);
    expect(p.poseOf(1)!.x, closeTo(299, 1e-9));
  });

  test('반복 끔: 마지막 틱에서 멈춘다', () {
    final p = _playerOf(marching(4))..advance(tickMs * 10);
    expect(p.position, 3);
    expect(p.poseOf(1)!.x, 294);
  });

  group('라이브 모드 (엔진이 매 틱 push)', () {
    RecordingPlayer live({_Log? log}) {
      final p = RecordingPlayer.live(tickMs: tickMs, lookaheadTicks: 2, maxLagTicks: 6, listener: log);
      log?.player = p;
      return p;
    }

    test('lookahead만큼 쌓이기 전에는 표시가 기다린다', () {
      final p = live()
        ..push(tickOf(0, enemies: [(1, 300)]))
        ..push(tickOf(1, enemies: [(1, 298)]))
        ..advance(tickMs * 5);
      expect(p.position, 0);
      p
        ..push(tickOf(2, enemies: [(1, 296)]))
        ..push(tickOf(3, enemies: [(1, 294)]))
        ..advance(tickMs * 5);
      expect(p.position, 1);
      expect(p.poseOf(1)!.x, 298);
    });

    test('이벤트는 기록 모드와 같은 시점에 알린다', () {
      final log = _Log();
      final p = live(log: log);
      marching(8).forEach(p.push);
      p.advance(tickMs * 2);
      expect(log.ahead.last, (4, 2.0));
      expect(log.now.last.$1, 2);
    });

    test('너무 뒤처지면 lookahead+maxLag 안으로 따라잡는다', () {
      final p = live();
      marching(30).forEach(p.push);
      p.advance(1);
      expect(p.position, greaterThanOrEqualTo(29 - 2 - 6));
    });

    test('오래 돌아도 버퍼가 커지지 않는다', () {
      final p = live();
      for (final t in marching(500)) {
        p
          ..push(t)
          ..advance(tickMs);
      }
      expect(p.bufferedTicks, lessThan(64));
      expect(p.position, greaterThan(400));
    });

    test('순풍(speed 2): 엔진이 주기마다 2틱 넣어도 같은 속도로 소비해 밀리지 않는다', () {
      final p = live();
      var t = 0;
      for (var period = 0; period < 300; period++) {
        for (var k = 0; k < 2; k++) {
          p.push(tickOf(t, enemies: [(1, 300 - t * 0.5)], speed: 2));
          t++;
        }
        // 화면 60Hz: 한 주기(50ms) = 3프레임.
        for (var f = 0; f < 3; f++) {
          p.advance(tickMs / 3);
        }
      }
      expect(p.bufferedTicks, lessThan(64));
      // 따라잡기 없이 lookahead 근처에서 따라간다.
      expect(t - 1 - p.position, inInclusiveRange(2, 2 + 6));
    });
  });
}
