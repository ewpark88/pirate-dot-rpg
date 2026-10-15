import 'package:game_core/src/battle/targeting.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 선원 사거리 표 (사용자 지시 2026-10-15): 계열마다 사거리(skills.json reach), 선원별 보정(crews.json reachBonus).
/// 탑다운에서 거리는 배 몸통(선체 캡슐) → 적 가장자리 — 위치 규칙은 topdown/top_geometry_test.dart.
void main() {
  final t = GameTables.load();
  final f = t.waves.field;

  test('모든 계열 공격·계열 스킬·선원 스킬에 사거리가 있다', () {
    for (final fam in t.skills.families) {
      for (final a in [fam.attack, fam.skill.area]) {
        expect(attackReach(a, f), isNotNull, reason: fam.id);
      }
    }
    for (final s in t.skills.crewSkills) {
      expect(attackReach(s.area, f), isNotNull, reason: s.id);
    }
  });

  test('계열 차등: 직사·관통 > 투척 > 강습·충격', () {
    double r(String id) => attackReach(t.skills.byId(id).attack, f)!;
    expect(r('direct'), greaterThan(r('lob')));
    expect(r('pierce'), greaterThan(r('lob')));
    expect(r('lob'), greaterThan(r('assault')));
    expect(r('lob'), greaterThan(r('shock')));
  });

  test('선원별 보정은 작게(±), 같은 계열 안에서도 다르다', () {
    for (final c in t.crews.crews) {
      expect(c.reachBonus.abs(), lessThanOrEqualTo(10), reason: c.id);
    }
    final direct = t.crews.crews.where((c) => c.family == 'direct').map((c) => c.reachBonus).toSet();
    expect(direct.length, greaterThan(1));
  });
}
