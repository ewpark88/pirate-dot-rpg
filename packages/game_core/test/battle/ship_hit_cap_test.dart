import 'package:game_core/game_core.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:test/test.dart';

/// 한 대 침몰 금지 (S3 발견 2026-10-16: 위협 재조정 뒤 스테이지 60에서 한 대에 침몰) — 한 대 피해 상한 waves.shipHitCap.
void main() {
  test('한 대 피해는 최대 HP × shipHitCap까지, 작은 피해는 그대로', () {
    final f = Field(stage: 60, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000));
    expect(f.hurtShip(BigNum.parse('1e30'), 0.08).toDouble(), closeTo(80, 1e-6));
    expect(f.shipHp.toDouble(), closeTo(920, 1e-6));
    expect(f.hurtShip(BigNum.from(5), 0.08), BigNum.from(5));
    expect(f.shipHp.toDouble(), closeTo(915, 1e-6));
  });

  test('상한이면 가라앉기까지 최소 1 ÷ shipHitCap 대', () {
    final f = Field(stage: 60, shipHpMax: BigNum.from(1000), shipHp: BigNum.from(1000));
    var hits = 0;
    while (!f.shipHp.isZero) {
      f.hurtShip(BigNum.parse('1e30'), 0.08);
      hits++;
    }
    expect(hits, 13);
  });
}
