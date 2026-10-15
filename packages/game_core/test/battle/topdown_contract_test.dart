import 'dart:convert';

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 탑다운 전환 T0 계약 (docs/plans/active/topdown-migration.md, S5 검토): 모두 선택 키 — 옛 기록·옆모습 본문은 그대로.
void main() {
  final t = GameTables.load();

  group('Settings.battleView', () {
    test('기본 top(T4), 탑다운이면 본문에 쓰지 않는다 — 키 없는 옛 세이브도 탑다운으로 읽힌다', () {
      const s = Settings();
      expect(s.battleView, 'top');
      expect(s.toJson().containsKey('battleView'), isFalse);
      expect(Settings.fromJson(s.toJson()).battleView, 'top');
      expect(Settings.fromJson(const Settings(battleView: 'side').toJson()).battleView, 'side');
    });

    test('SetSetting(battleView, top) → 왕복', () {
      final top = const Settings().withValue('battleView', 'top');
      expect(top.battleView, 'top');
      expect(Settings.fromJson(top.toJson()).battleView, 'top');
      expect(() => const Settings().withValue('battleView', 1), throwsArgumentError);
    });
  });

  group('BattleView·EnemyView', () {
    test('옛 JSON(키 없음) → side·배 위치 없음·heading 0, 적 heading = 왼쪽', () {
      final old = BattleView.empty.toJson();
      expect(old.keys, isNot(containsAll(['mode', 'shipX', 'shipY', 'shipHeading'])));
      final v = BattleView.fromJson(old);
      expect([v.mode, v.shipX, v.shipY, v.shipHeading], ['side', null, null, 0]);
      final e = EnemyView.fromJson(const {'id': 1, 'kind': 'crab', 'x': 10, 'y': 20, 'hpRatio': 1});
      expect(e.heading, EnemyView.sideHeading);
      expect(e.toJson().containsKey('heading'), isFalse);
    });

    test('top 값 왕복', () {
      const v = BattleView(
        shipHp: BigNum.one,
        shipHpMax: BigNum.one,
        mode: 'top',
        shipX: 135,
        shipY: 240,
        shipHeading: 0.5,
        enemies: [EnemyView(id: 2, kind: 'crab', x: 1, y: 2, hpRatio: 0.5, heading: 1.25)],
      );
      final back = BattleView.fromJson(jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>);
      expect([back.mode, back.shipX, back.shipY, back.shipHeading], ['top', 135, 240, 0.5]);
      expect(back.enemies.single.heading, 1.25);
    });
  });

  test('AttackFired: fromX·fromY·angle 선택 필드 왕복, 없으면 본문에 없음', () {
    const plain = AttackFired(3, crewId: 'octo', family: 'lob', targetIds: [1], x: 10, y: 20);
    expect(plain.toJson().keys, isNot(contains('angle')));
    const top = AttackFired(
      3,
      crewId: 'octo',
      family: 'lob',
      targetIds: [1],
      x: 10,
      y: 20,
      fromX: 135,
      fromY: 240,
      angle: -1.5,
    );
    final back = GameEvent.fromJson(top.toJson()) as AttackFired;
    expect([back.fromX, back.fromY, back.angle], [135, 240, -1.5]);
  });

  test('waves.top: 배 중심은 전장 안, 보스 standoff는 배·보스 반경 이상이고 모든 계열 사거리 안(둘레 기준)', () {
    final top = t.waves.top;
    expect(top.validate(), isEmpty);
    final gap = top.bossStandoff - top.shipRadius - top.bossRadius; // 배 둘레 → 보스 가장자리
    for (final fam in t.skills.families) {
      final minBonus = t.crews.crews
          .where((c) => c.family == fam.id)
          .map((c) => c.reachBonus)
          .reduce((a, b) => a < b ? a : b);
      expect(gap, lessThanOrEqualTo(fam.attack.raw.number('reach') * top.reachScale + minBonus), reason: fam.id);
    }
  });
}
