# 기획: 배 위협 규칙 — 원거리 적 · 가까이 등장 (S5 리드)

- 상태: 초안(2026-10-16) — S1 → 사용자 확인 뒤 착수 · 사용자 결정: (a) 원거리 적 (b) 가까이 등장 · 담당: 엔진 S5 · 표·sim S2 · 연출 S3
- 문제(사용자): 적이 배에 닿아야만 아프다 → 강해지면 배가 거의 안 다친다. 목표: **평소 파밍 파당 배 피해 10~40%**, 침몰은 **벽(못 넘는 스테이지)에서만**(S2 sim 지표 farmWaveDamagePct·wallSinkSec).

## (a) 원거리 적
- 일부 적 종류가 다가오는 동안 침·가시·물대포를 쏜다. **보이는 발사체**(날아오는 시간 있음), 피할 수 없다(자동 전투라 회피 조작 없음). 한 발 피해 = 접촉 공격 × `damageRatio`(제안 0.35).
- 표(S2, regions.json enemies[] 선택 키): `ranged: {range, intervalSec, damageRatio, projectileSpeed, kind}`
  - 제안: 갈매기류(gull·stormgull·snowgull) 깃털 침, 가시류(urchin·starfish·puffer) 가시, 날치(flyingfish) 물대포, 펭귄(penguin) 눈뭉치, 화염새(firebird) 불씨.
  - range = 배 몸통에서 거리(제안 90), intervalSec 2.5, projectileSpeed 120.
- 엔진(S5): 원거리 적은 range 안에 들어오면 쏜다(계속 다가오면서 — 멈추지 않음, 사용자 '접근 중'). 발사 = `EnemyFired(enemyId, fromX, fromY, flightTicks, kind)` → 도착 틱에 `ShipDamaged(fromX, fromY)`. 기절·감속 중엔 쏘지 않는다. 결정론.
- 연출(S3): 발사체(종류별 작은 도트), 배 맞은 쪽 반짝임(이미 ShipDamaged.fromX/Y).

## (b) 가까이 등장
- 파 시작과 도중에 몇 마리가 배 근처(접근 원 안, 배 몸통에서 `nearDistance`)에서 **솟아오른다**. **물보라 예고 0.6초** 뒤 등장 — 예고 동안은 맞지도 때리지도 않는다.
- 표(S2, waves.top 선택 키): `nearSpawn: {ratio, distanceMin, distanceMax, warnSec, midWave}`
  - 제안: ratio 0.15(한 파의 15%), 몸통에서 40~80단위, warnSec 0.6, midWave true(파 시작에 절반, 파 도중에 절반).
- 엔진(S5): 스폰 패턴(swarm·scatter·arc)과 별개로, 정해진 비율의 적을 가까운 자리에 놓고 등장 대기(Foe.holdSec 재사용 — 대기 중 조준·이동·겹침 제외). 예고 이벤트 `EnemyEmerging(enemyId, x, y, warnTicks)`, 대기가 끝나면 보통 적처럼. 결정론.
- 연출(S3): 물보라 예고(원·거품 0.6초) → 솟아오름.

## 계약 추가 (S2)
- 이벤트 `EnemyFired`·`EnemyEmerging`(위), `EnemyView.emerging`(선택 키, 예고 중), regions enemies `ranged`·waves.top `nearSpawn` 모델.

## 수용 기준
1. 원거리 적: range 안에서 intervalSec마다 `EnemyFired` 1번 → flightTicks 뒤 `ShipDamaged`(피해 = 접촉 × damageRatio, fromX/Y = 쏜 자리). 기절 중엔 안 쏨.
2. 가까이 등장: 한 파의 ratio만큼 몸통에서 40~80 자리, warnSec 동안 `emerging`(조준 안 됨·이동 안 함·접촉 없음) → 그 뒤 보통 적.
3. 키가 없으면 지금과 결과가 같다(시나리오·sim 해시).
4. sim(S2): 파밍 파당 배 피해 10~40%, 침몰은 벽에서만, balance crews 그대로.
5. 150마리 + 발사체 한 틱 < 2ms.
