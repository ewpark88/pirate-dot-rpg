import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/replay/recording_player.dart';
import 'package:pirate_dot/render/scene/damage_numbers.dart';

import 'helpers.dart';

/// 피해 숫자 가독성 (platform 지적 E8: 배 앞에서 숫자가 쌓여 읽히지 않음) — 기준 gif처럼 '읽히는' 숫자.
void main() {
  final spec = tables.juice.damageNumber;
  final dn = tables.juice.raw.obj('damageNumber');
  DamageNumbers fresh() => DamageNumbers(
    spec,
    tables.juice.maxDamageNumbers,
    mergeMs: dn.number('mergeMs'),
    stackRows: dn.integer('stackRows'),
  );
  final mergeMs = dn.number('mergeMs');
  final stackRows = dn.integer('stackRows');
  double drawnY(DamageNumbers n, DamageNumber d) => d.y - n.riseOf(d);

  test('같은 적·짧은 시간(mergeMs) 안의 일반 피해는 숫자 하나로 합치고 다시 튀어 오른다', () {
    final n = fresh()
      ..add(BigNum.from(10), 100, 80, DamageKind.normal, key: 7)
      ..update(mergeMs / 2)
      ..add(BigNum.from(15), 102, 81, DamageKind.normal, key: 7);
    expect(n.active, hasLength(1));
    expect(n.active.single.amount.toDouble(), 25);
    expect(n.active.single.ageMs, 0);
  });

  test('합치기 시간(mergeMs, 최소 300ms — 디자인 개편)이 지나면 같은 적이어도 새 숫자', () {
    final n = fresh()
      ..add(BigNum.from(10), 100, 80, DamageKind.normal, key: 7)
      ..update(math.max(mergeMs, 300) + 1)
      ..add(BigNum.from(15), 100, 80, DamageKind.normal, key: 7);
    expect(n.active, hasLength(2));
  });

  test('겹치는 자리의 새 숫자는 위로 비켜 쌓는다(한 줄 높이 이상), 최대 stackRows줄', () {
    final n = fresh();
    for (var i = 0; i < stackRows; i++) {
      n.add(BigNum.from(10 + i), 100, 80, DamageKind.normal, key: i);
    }
    final ys = [for (final d in n.active) drawnY(n, d)]..sort();
    expect(ys, hasLength(stackRows));
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i] - ys[i - 1], greaterThanOrEqualTo(DamageNumbers.lineHeight(1)));
    }
    // 줄이 다 차면 맨 위 숫자에 합친다 → 개수는 그대로, 합계 보존.
    n.add(BigNum.from(100), 100, 80, DamageKind.normal, key: 99);
    expect(n.active, hasLength(stackRows));
    final total = n.active.fold<double>(0, (s, d) => s + d.amount.toDouble());
    expect(total, 10 + 11 + 12 + 100);
  });

  test('떨어진 자리의 숫자는 비키지 않는다', () {
    final n = fresh()
      ..add(BigNum.from(10), 100, 80, DamageKind.normal, key: 1)
      ..add(BigNum.from(10), 160, 80, DamageKind.normal, key: 2);
    expect(n.active.map((d) => d.y), [80, 80]);
  });

  test('치명타는 일반 숫자에 합치지 않고(색이 다름) 비켜 쌓기만 한다', () {
    final n = fresh()
      ..add(BigNum.from(10), 100, 80, DamageKind.normal, key: 3)
      ..add(BigNum.from(40), 100, 80, DamageKind.crit, key: 3);
    expect(n.active.map((d) => d.kind), [DamageKind.normal, DamageKind.crit]);
    expect(n.active.last.y, lessThan(80));
  });

  test('숫자가 맞은 적을 따라간다(보스 이동·돌진) — 상대 위치 유지, 죽으면 그 자리에 남음', () {
    final nums = fresh();
    final boss = EnemyPose()
      ..id = 7
      ..boss = true
      ..drawX = 100
      ..drawY = 50;
    nums.add(BigNum.from(999), 100, 40, DamageKind.crit, key: 7, on: boss);
    final rel = [for (final n in nums.active) (n.x - boss.drawX, n.y - boss.drawY)];
    EnemyPose? at(int id) => id == 7 ? boss : null;
    for (var i = 0; i < 20; i++) {
      boss
        ..drawX += 9
        ..drawY += 4;
      nums.update(16, at);
      for (final (k, n) in nums.active.indexed) {
        expect((n.x - boss.drawX, n.y - boss.drawY), rel[k]);
      }
    }
    final last = [for (final n in nums.active) (n.x, n.y)];
    nums.update(16, (_) => null); // 죽음
    boss.drawX += 50;
    nums.update(16, at);
    expect([for (final n in nums.active) (n.x, n.y)], last);
  });

  test('따라가다 서로 겹치면 나중 숫자를 위 줄로 비킨다(탑 실기기 87.1.65K)', () {
    final nums = fresh();
    final a = EnemyPose()
      ..id = 1
      ..drawX = 0
      ..drawY = 0;
    final b = EnemyPose()
      ..id = 2
      ..drawX = 200
      ..drawY = 0;
    nums
      ..add(BigNum.from(87), 0, -10, DamageKind.normal, key: 1, on: a)
      ..add(BigNum.from(1650), 200, -10, DamageKind.normal, key: 2, on: b);
    b.drawX = 4; // 두 적이 한자리로 모임
    nums.update(16, (id) => id == 1 ? a : b);
    final [n1, n2] = nums.active;
    final line = DamageNumbers.lineHeight(nums.scaleOf(n2)) * nums.tall;
    expect(((n1.y - nums.riseOf(n1)) - (n2.y - nums.riseOf(n2))).abs(), greaterThanOrEqualTo(line - 1e-6));
  });
}
