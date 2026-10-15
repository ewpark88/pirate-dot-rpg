import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/battle/topdown/top_field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/testing.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 탑다운 전장 모양 (탑다운 전환 T1, docs/contracts/requests/platform-topdown-t0.md).
/// waves.json `top` 절이 들어오기 전이라 같은 값을 여기서 만든다(S2 계약 초안 + S5 검토 값).
const topField = TopField(
  width: 270,
  height: 480,
  shipX: 135,
  shipY: 240,
  shipRadius: 20,
  mobRadius: 6,
  bossRadius: 24,
  spawnMargin: 12,
  approachRadius: 206,
  approachBoost: 5,
  swarmGroupsMin: 1,
  swarmGroupsMax: 3,
  swarmSpreadDeg: 20,
  separation: 0.5,
  bossStandoff: 48,
  bossOrbitDegPerSec: 12,
  reachScale: 1,
);

void main() {
  final t = GameTables.load();
  final w = t.waves;
  final geo = TopGeometry(w, topField);
  final start = DateTime.utc(2026, 11);
  SystemContext ctx(int seed) =>
      SystemContext(tables: t, clock: ManualClock(start), rng: XorShiftRng(seed), onEvent: (_) {});
  Field field() => Field(stage: 30, shipHpMax: BigNum.from(100), shipHp: BigNum.from(100));
  double dist(Foe e) => math.sqrt(math.pow(e.x - topField.shipX, 2) + math.pow(e.y - topField.shipY, 2));
  double angleOf(Foe e) => math.atan2(e.y - topField.shipY, e.x - topField.shipX);

  Foe mob(double x, double y, {int id = 1, String layer = 'surface', bool boss = false}) => Foe(
    id: id,
    kind: 'crab',
    layer: layer,
    x: x,
    y: y,
    maxHp: BigNum.from(1e9),
    speed: 20,
    attack: BigNum.one,
    gold: BigNum.one,
    boss: boss,
  );

  group('스폰', () {
    test('사방에서: 모두 화면 밖, 접근 원 밖, 1~3개 방향 묶음, 같은 시드면 같은 자리', () {
      List<(double, double)> spawn(int seed) {
        final f = field();
        geo.spawnWave(f, 30, ctx(seed), count: 14);
        return [for (final e in f.foes) (e.x, e.y)];
      }

      expect(spawn(4), spawn(4));
      final dirs = <int>{};
      for (var seed = 1; seed <= 40; seed++) {
        final f = field();
        geo.spawnWave(f, 30, ctx(seed), count: 14);
        expect(f.foes, hasLength(14));
        for (final e in f.foes) {
          expect(geo.onScreen(e), isFalse, reason: '화면 밖에서 나온다');
          expect(dist(e), greaterThanOrEqualTo(topField.approachRadius - 1e-6));
          dirs.add(((angleOf(e) + math.pi) / (math.pi / 2)).floor() % 4); // 사분면
        }
      }
      expect(dirs, hasLength(4), reason: '여러 판이면 네 방향 모두에서 온다');
    });

    test('도착 시간: 위·옆 어느 방향이든 차이 ≤ 10% (접근 원 밖은 해류)', () {
      double arrive(double angle) {
        final e = mob(0, 0);
        final d = math.max(
          math.min(
                (math.cos(angle) == 0 ? double.infinity : (topField.width / 2) / math.cos(angle).abs()),
                (math.sin(angle) == 0 ? double.infinity : (topField.height / 2) / math.sin(angle).abs()),
              ) +
              topField.spawnMargin +
              topField.mobRadius,
          topField.approachRadius,
        );
        e
          ..x = topField.shipX + math.cos(angle) * d
          ..y = topField.shipY + math.sin(angle) * d;
        var time = 0.0;
        const dt = 0.05;
        while (!geo.advance(e, 20, dt)) {
          time += dt;
        }
        return time;
      }

      final side = arrive(0);
      final upward = arrive(-math.pi / 2);
      final corner = arrive(math.atan2(topField.height, topField.width));
      expect((upward - side).abs() / side, lessThanOrEqualTo(0.1));
      expect((corner - side).abs() / side, lessThanOrEqualTo(0.1));
      // 옆모습: spawnX → shipX 186을 같은 속도로 걷는 시간과 비슷하다.
      expect((side - (w.field.spawnX - w.field.shipX) / 20).abs() / side, lessThanOrEqualTo(0.15));
    });
  });

  group('조준 (배 둘레 → 적 가장자리)', () {
    AttackDef attack(String family) => t.skills.byId(family).attack;

    test('사거리: lob reach 안이면 맞고, 밖이면 안 맞는다 · 화면 밖은 안 맞는다', () {
      final a = attack('lob');
      final reach = a.raw.number('reach');
      final inside = topField.shipRadius + topField.mobRadius + reach - 1;
      final near = mob(topField.shipX, topField.shipY - inside);
      final far = mob(topField.shipX, topField.shipY + inside + 2, id: 2);
      expect(geo.eligible(a, [near, far]), [near]);
      final off = mob(-5, topField.shipY, id: 3);
      expect(geo.eligible(attack('direct'), [off]), isEmpty);
    });

    test('관통: 배 → 첫 대상 방향 광선, 반대편은 안 맞음', () {
      final a = attack('pierce');
      final first = mob(topField.shipX, topField.shipY - 40);
      final behind = mob(topField.shipX, topField.shipY - 80, id: 2);
      final opposite = mob(topField.shipX, topField.shipY + 50, id: 3);
      final aside = mob(topField.shipX + 30, topField.shipY - 60, id: 4);
      final v = geo.aimMany(a, 1, [first, behind, opposite, aside], XorShiftRng(1)).single;
      expect(v.hits.map((h) => h.foe), [first, behind]);
      expect(v.hits.last.factor, lessThan(1), reason: '관통 감쇠');
    });

    test('충격: 배 둘레 고리 — 사방 모두, range 밖은 안', () {
      final a = attack('shock');
      final r = topField.shipRadius + topField.mobRadius + a.range - 1;
      final ring = [
        for (var i = 0; i < 4; i++)
          mob(topField.shipX + math.cos(i * math.pi / 2) * r, topField.shipY + math.sin(i * math.pi / 2) * r, id: i),
      ];
      final out = mob(topField.shipX + r + 10, topField.shipY, id: 9);
      final v = geo.aimMany(a, 1, [...ring, out], XorShiftRng(1)).single;
      expect(v.hits.map((h) => h.foe).toSet(), ring.toSet());
      expect((v.x, v.y), (topField.shipX, topField.shipY));
    });

    test('강습: 가장 가까운 적 방향 부채꼴 — 등 뒤는 안 맞음, 아주 가까우면 각도 무관', () {
      final a = attack('assault');
      final edge = topField.shipRadius + topField.mobRadius;
      final front = mob(topField.shipX + edge + 3, topField.shipY);
      final frontFar = mob(topField.shipX + edge + 30, topField.shipY + 4, id: 2);
      final back = mob(topField.shipX - edge - 30, topField.shipY, id: 3);
      final hugging = mob(topField.shipX, topField.shipY - edge - 8, id: 4);
      final hits = geo.aimMany(a, 1, [front, frontFar, back, hugging], XorShiftRng(1)).single.hits.map((h) => h.foe);
      expect(hits, containsAll([front, frontFar, hugging]));
      expect(hits, isNot(contains(back)));
    });

    test('보스는 멀리 서도(standoff 100) 충격·강습이 닿는다 — 옆모습과 같은 규칙', () {
      final boss = mob(topField.shipX, topField.shipY - 100, boss: true);
      for (final id in ['shock', 'assault']) {
        expect(geo.aimMany(attack(id), 1, [boss], XorShiftRng(1)).single.hits.single.foe, boss, reason: id);
      }
    });

    test('투척: 가장 붐비는 곳 중심 · 여러 발은 서로 다른 무리', () {
      final a = attack('lob');
      final pack = [for (var i = 0; i < 4; i++) mob(topField.shipX + 60 + i * 3.0, topField.shipY - 40, id: i)];
      final lone = mob(topField.shipX - 50, topField.shipY + 30, id: 9);
      final vs = geo.aimMany(a, 2, [...pack, lone], XorShiftRng(1));
      expect(vs.first.hits.map((h) => h.foe).toSet(), pack.toSet());
      expect(vs.last.hits.single.foe, lone);
    });

    test('8계열 모두 사방의 적을 맞힌다(옆모습처럼 오른쪽만이 아님)', () {
      final foes = [
        for (var i = 0; i < 8; i++)
          mob(topField.shipX + math.cos(i * math.pi / 4) * 50, topField.shipY + math.sin(i * math.pi / 4) * 50, id: i),
      ];
      for (final fam in t.skills.families) {
        final hit = <Foe>{};
        for (var k = 0; k < 20; k++) {
          for (final v in geo.aimMany(fam.attack, 1, foes, XorShiftRng(k + 1))) {
            hit.addAll(v.hits.map((h) => h.foe));
          }
          foes.add(foes.removeAt(0)); // 가장 가까운 적이 돌아가며 바뀌게
          for (var i = 0; i < foes.length; i++) {
            foes[i].x += i.isEven ? 0.01 : -0.01;
          }
        }
        expect(hit.length, greaterThanOrEqualTo(2), reason: fam.id);
      }
    });
  });

  group('움직임', () {
    test('밀어내기: 배에서 바깥으로(방사), 접근 원 밖으로는 안', () {
      final e = mob(topField.shipX - 30, topField.shipY - 40);
      final before = angleOf(e);
      geo.push(e, 10);
      expect(dist(e), closeTo(60, 1e-9));
      expect(angleOf(e), closeTo(before, 1e-9));
      geo.push(e, 1000);
      expect(dist(e), closeTo(topField.approachRadius, 1e-9));
    });

    test('보스: 위에서 나와 standoff 원에 닿으면 멈추고 원을 따라 돈다 — 모든 계열 사거리 안', () {
      final f = field();
      final boss = mob(0, 0, boss: true);
      f.foes.add(boss);
      geo.placeBoss(f);
      expect(boss.x, topField.shipX, reason: '배 위쪽');
      expect(dist(boss), closeTo(topField.approachRadius + topField.bossRadius, 1e-9), reason: '접근 원 바로 밖에서 출발');
      var touched = false;
      for (var i = 0; i < 400 && !touched; i++) {
        touched = geo.advance(boss, 25, 0.05);
      }
      expect(touched, isTrue);
      expect(dist(boss), closeTo(topField.bossStandoff, 1e-6));
      final a0 = angleOf(boss);
      geo.settle(f, 1);
      expect(dist(boss), closeTo(topField.bossStandoff, 1e-6));
      expect(angleOf(boss) - a0, closeTo(12 * math.pi / 180, 1e-9));
      for (final fam in t.skills.families) {
        if (fam.attack.excludeLayers.contains('surface')) continue;
        expect(geo.eligible(fam.attack, [boss]), [boss], reason: '${fam.id}: 보스는 늘 사거리 안');
      }
    });

    test('겹침 풀기: 같은 자리 두 마리는 벌어지고, 배 둘레 안으로 들어가지 않는다', () {
      final f = field();
      final a = mob(topField.shipX + 27, topField.shipY);
      final b = mob(topField.shipX + 28, topField.shipY + 1, id: 2);
      f.foes.addAll([a, b]);
      for (var i = 0; i < 30; i++) {
        geo.settle(f, 0.05);
      }
      expect(math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2)), greaterThan(topField.mobRadius * 1.5));
      for (final e in [a, b]) {
        expect(dist(e), greaterThanOrEqualTo(topField.shipRadius + topField.mobRadius - 1e-9));
      }
    });

    test('배 등급별 반경: 둘레 거리·접촉·포구가 그 반경으로', () {
      final big = TopGeometry(w, topField.withShipRadius(32));
      final e = mob(topField.shipX + 32 + 6 + 10, topField.shipY);
      expect(big.edge(e), closeTo(10, 1e-9));
      for (var i = 0; i < 100 && !big.advance(e, 20, 0.05); i++) {}
      expect(dist(e), closeTo(32 + topField.mobRadius, 1e-9));
      expect(big.muzzle(topField.shipX, 0).y, closeTo(topField.shipY - 32, 1e-9));
      // 배 등급별(ship_tiers topRadius): 스테이지 1 소형선 28, 30 슬루프 29, 80 군함 32.
      double r(int stage) => (geometryFor('top', t, stage) as TopGeometry).top.shipRadius;
      expect([r(1), r(30), r(80), r(150)], [28, 29, 32, 32]);
      expect(geometryFor('side', t, 80), isA<SideGeometry>());
    });

    test('옆모습 SideGeometry는 지금 규칙 그대로(앞머리에서 멈춤, 오른쪽으로 밀림)', () {
      final s = SideGeometry(w);
      final stop = w.field.shipX + w.field.contactGap;
      final e = mob(stop + 5, w.field.shipY);
      expect(s.advance(e, 20, 0.05), isFalse);
      expect(e.x, stop + 4);
      e.x = stop;
      expect(s.advance(e, 20, 0.05), isTrue);
      s.push(e, 10);
      expect(e.x, stop + 10);
      expect(s.mode, 'side');
      expect(geo.mode, 'top');
    });
  });
}
