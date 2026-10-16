# 기획: 보스 행동 v2 — 보이는 패턴 2~3개를 돌아가며 (S5 리드)

- 상태: 초안(2026-10-16) — S1 → 사용자 확인 · 담당: 엔진 S5 · 수치 S2 · 연출 S3
- 사용자 지시(S1 중계): "보스가 체력만 좋고 폭탄도 안 쏘고 배에 달라붙어 몸통박치기만 한다 — 바보 같은 보스라 너무 잡기 쉽다."

## 0. 지금 (2026-10-16 확인)
- **본 보스(해역·중간·현상금)**: 엔진은 standoff 100 원에서 멈춰 돌고, 접촉 간격마다 `BossFired` + 배 피해(combat.dart). 하지만 **렌더가 `BossFired`를 그리지 않아** 쏘는 게 안 보이고 배만 깎인다 → '폭탄도 안 쏜다'.
- **'붙어서 박치기'는 돌발 이벤트 ambush의 sea_serpent**: 일반 적 취급(boss=false), 체력 = 보스 × 0.4, 공격 = 보스 공격 — 배 몸통까지 와서 접촉만 한다.
- 보스 고유 기계(regions.json `mechanic`)는 7개 중 6개 보스에 하나씩만: frontArmor·shield·lava·tentacles·summoner. 일반 보스 7종(enemy_ship 등)은 기계가 없다.
- 렌더 몫 즉시 수정(이 기획과 별개, S3): `BossFired`를 탄(포탄 비행 0.3초) + 배 피격으로 그린다.

## 목적 (설계서 1장)
- 시원한가: 보스가 '뭔가 한다' — 예고 → 큰 동작 → 피하거나(못 피함, 자동) 버티는 긴장. 처치가 '이겼다'가 된다.
- 단순한가: 조작 추가 없음(자동 전투). 예고가 눈으로 읽히면 충분. 패턴 수는 보스당 2~3.
- 피로가 없는가: 30초 타이머 안에 패턴 3~5번. 같은 보스는 같은 순서(외우는 재미), 난수는 위치만.
- 공정한가: 패턴 피해 합계 = 지금 보스 원거리 피해 총량 × 1.0~1.3(S2 sim). 선원이 강하면 패턴을 덜 본다(빨리 잡음) — 강해짐이 보인다.

## 1. 패턴 5종 (bosses `patterns`: 순서 목록, 하나 끝나면 다음, 끝나면 처음부터)
| 패턴 | 예고 | 동작 | 피해 | 이벤트 |
| --- | --- | --- | --- | --- |
| `volley` 조준 탄막 | 부채꼴 예고선 `warnSec` 0.6 | 배를 향해 부채꼴 `count` 3~5발, 탄속 `speed` | 발마다 공격 × `damageRatio`(0.3) | `BossPattern(kind, warnTicks, x, y, angle, count)` → 탄마다 `EnemyFired`(kind 'boss_shell') |
| `charge` 돌진 | 몸 흔들기 + 배까지 빨간 선 `warnSec` 0.8 | 배로 돌진(속도 × `speedMul` 4) → 몸통에 닿으면 큰 피해 → standoff 원으로 복귀 | 공격 × `damageRatio`(1.5) 한 번 | `BossPattern(kind 'charge')` → `ShipDamaged` |
| `summon` 졸개 소환 | 보스 둘레 물보라 0.6 | 잡몹 `count` 3~5 (지금 summoner 기계) | 졸개 접촉 | `BossPattern(kind 'summon')` + 가까이 등장 길(EnemyEmerging) 재사용 |
| `blast` 장판 | 배 둘레 원 `radius`(배 반경 × 2) 빨간 예고 `warnSec` 1.2 | 폭발 | 공격 × `damageRatio`(1.0) | `BossPattern(kind 'blast')` → `ShipDamaged` |
| `shell` 보호막 | (지금 shield 기계) | 피해 × factor, 깨는 계열 | — | 기존 |
- 패턴 사이 쉼 `restSec` 2~3초(이때 기존 원거리 기본 공격 `BossFired`). 쉼이 있어 '틈에 몰아친다'가 보인다.
- 모든 배 피해는 S2 `Field.hurtShip`(한 대 상한 shipHitCap 8%)을 거친다 → 큰 패턴도 한 방에 가라앉지 않는다. 돌진만 상한 × 2(표 `capMul`).
- 보스 기절 중엔 패턴 타이머 멈춤(기절 선원의 가치), 예고 중 기절되면 패턴 취소.

## 2. 보스별 배정 (S2가 숫자 조정)
| 보스 | 패턴 순환 | 비고 |
| --- | --- | --- |
| enemy_ship | volley(3) → rest | 첫 보스(튜토리얼): 하나만 |
| raider_ship | volley(3) → charge | 중간 보스 |
| storm_pirate | volley(5) → blast | |
| icebreaker | charge → volley(3) | |
| fire_pirate | blast → volley(5) | |
| deep_sub | summon → volley(3) | |
| ghost_ship | summon → charge | |
| giant_hermit | charge → volley(3) + frontArmor | 해역 보스: 기계 + 2패턴 |
| thunder_ray | blast → volley(5) + shield | |
| iceberg_walrus | charge → blast + shield | |
| lava_whale | lava(기존) → volley(5) → charge | |
| kraken | tentacles(기존) → summon → blast | |
| ghost_admiral | summon(기존) → volley(5) → charge | 마지막: 3패턴 |
| sea_serpent (ambush) | charge 반복 | 일반 적 → 'ambush 보스'로: standoff에서 돌진 패턴만. 체력 그대로 |
- 현상금 보스: 해당 보스 패턴 + 단계(tier)마다 쉼 −10%(최소 1초).

## 3. 엔진 (S5)
1. regions.json bosses `patterns: [{type, warnSec, ...}]`, `restSec`(없으면 지금처럼 기본 원거리만 — 옛 결과 그대로).
2. Field 보스 상태 `pattern{index, phase: rest|warn|act|return, ticksLeft, aimX, aimY}` — 결정론(위치 난수만 ctx.rng).
3. 돌진: TopGeometry에 보스 돌진 이동(standoff 무시 → 몸통 닿음 → 복귀). 탄막: 배 위협 (a) 탄 길(`enemyShots`) 재사용 + 부채꼴 각도별 명중(빗나간 탄 없음 — 배는 안 움직임, 각도는 연출).
4. 이벤트 `BossPattern(kind, phase: warn|act, warnTicks, x, y, angle?, count?, radius?)` — 계약 S2.
5. ambush sea_serpent: `boss` 플래그 대신 `eventBoss`(standoff + 패턴, 파 끝 판정 제외는 그대로).

## 4. 수치 (S2) · 5. 연출 (S3)
- S2: 패턴 피해 비율·쉼·예고 길이 → sim '보스 30초 안 배 피해 25~45%', 최약 편성 실패율.
- S3: 예고선(부채꼴 반투명 빨강)·돌진 빨간 선 + 몸 흔들기·장판 원 깜빡임(빨라짐)·소환 물보라·탄 비행·`BossFired` 포탄. 예고는 색맹 대비 모양(선·원 테두리)으로도 구별.

## 수용 기준
1. patterns 없는 표 = 지금 결과 그대로(시나리오·sim 해시).
2. 각 패턴: 예고 → 동작 → 이벤트 순서·틱(단위 테스트), 같은 시드 같은 결과.
3. 돌진 뒤 standoff 원 복귀, 기절 시 예고 취소.
4. 한 대 상한: 어느 패턴도 배 최대 HP 8%(돌진 16%) 넘지 않음.
5. 보스 30초 sim 기준(S2), 렌더 골든(예고 3종, S3).

## 결정 필요 (사용자)
1. 패턴 배정(2절)이 보스 그림과 맞는지.
2. 예고 길이: 짧게(0.6초, 긴장) vs 길게(1.2초, 읽기 쉬움) — 초안은 패턴마다 0.6~1.2.
3. 바다 괴물(ambush)을 돌진하는 보스로 바꿀지(초안: 바꿈).
