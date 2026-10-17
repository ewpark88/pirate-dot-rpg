import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

/// 사용자 요청(2026-10-17): 근접(강습) 선원은 사정거리가 배 주변(배 지킴이), 선원 몸이 날아가는 출격은 없다.
void main() {
  final t = GameTables.load();
  final geo = geometryFor(t, 1) as TopGeometry;
  final top = geo.top;
  final assault = t.skills.byId('assault').attack;

  Foe mob(double dx, double dy, {bool boss = false}) => Foe(
    id: 1,
    kind: 'crab',
    layer: 'surface',
    x: top.shipX + dx,
    y: top.shipY + dy,
    maxHp: BigNum.one,
    speed: 0,
    attack: BigNum.one,
    gold: BigNum.one,
    boss: boss,
  );

  test('출격 없음: 어떤 계열도 behavior sortie가 없다(강습은 배 위 휘두르기, 공중은 일반 탄)', () {
    for (final f in t.skills.families) {
      expect(
        f.attack.raw.has('behavior') ? f.attack.raw.obj('behavior').strOrNull('kind') : null,
        isNot('sortie'),
        reason: f.id,
      );
    }
    expect(t.skills.byId('air').attack.raw.has('projectile'), isTrue);
  });

  test('배 지킴이: 강습 reach는 배 둘레 22 — 배 가까운 적만, 멀리 선 보스에게는 bossReach로 닿는다', () {
    expect(assault.raw.number('reach'), 22);
    final near = mob(0, -(top.hullHalfLength + top.mobRadius + 15));
    final far = mob(0, -(top.hullHalfLength + top.mobRadius + 60));
    expect(geo.eligible(assault, [near]), [near]);
    expect(geo.eligible(assault, [far]), isEmpty);
    final boss = mob(0, -top.bossStandoff, boss: true);
    expect(geo.eligible(assault, [boss]), [boss]);
    for (final c in t.crews.crews.where((c) => c.family == 'assault')) {
      expect(c.aim!.number('reach'), lessThanOrEqualTo(22), reason: c.id);
    }
  });
}
