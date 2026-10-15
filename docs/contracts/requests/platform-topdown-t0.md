# 요청: 탑다운 T0 계약 + T1 연결 지점 (platform S5 → S2·S1)

- 날짜 2026-10-15 · 계획 `docs/plans/active/topdown-migration.md` · T1 리드 S5
- 목표: 옆모습 전투를 그대로 두고, 같은 엔진에 **탑다운 모드**를 더한다. 경제(골드·카드·보스 클리어·진행·sim)는 손대지 않는다.
- 원칙
  - 계약은 **선택 키만** 더한다. 기존 세이브·이벤트 JSON·골든·시나리오는 그대로 통과해야 한다.
  - 모드별 차이는 '모양'(어디서 나오고, 어디로 가고, 누가 사거리 안인가)뿐이다. 피해 공식·스킬·보스 패턴·처치 보상은 공용 코드를 그대로 쓴다.

## A~C. 계약·좌표·표 — **S2 초안 채택**(2026-10-15, S2 → S5)
- `Settings.battleView`, `BattleView.mode/shipX/shipY/shipHeading`, `EnemyView.heading`, AttackFired `fromX/fromY/angle`, SkillCast·BossFired `angle` — 모두 선택 키.
- 좌표: 왼쪽 위 (0,0), 배 중심 고정 (`top.shipX`, `top.shipY`), `waves.json` `top` {width 270, height 480, shipX 135, shipY 240, spawnMargin, bossStandoff, reachScale}.
- S5 검토 의견(S2에 전달, 균형이 걸린 것):
  1. **거리 = 배 둘레 → 적 가장자리**(`dist − shipRadius − foeRadius ≤ reach`). 표에 shipRadius 20 · mobRadius 6 · bossRadius 24.
     `bossStandoff` 110이면 충격(85)·강습(range 40)이 보스를 못 맞힌다. 48(= 20 + 24 + 4) 근처를 권한다.
  2. **도착 시간 맞추기**: `approachRadius`(186 + shipRadius) 원 밖에서는 ×`approachBoost`(3)로 다가온다. 그러면 위·아래·옆 어디서 나와도 옆모습(186)과 같은 시간에 닿는다. 한 파 안 간격(i × spawnSpacing)도 유지한다.
  3. 폭 270이면 좌우로 보이는 거리가 135라서, 옆으로 오는 적에게 첫 발이 늦어질 수 있다 → sim으로 확인.
  4. 무리: `swarmGroups` [1,3] · `swarmSpreadDeg` 40.

## D. 계열 8종 2D 모양 (T1, `battle/topdown/`)
| 계열 | shape | top 규칙 |
| --- | --- | --- |
| 투척 lob | circle | 가장 붐비는 적 중심 반지름 radius(옆모습과 같음) |
| 직사 direct | single | 배에서 가장 가까운 적 |
| 관통 pierce | line | 배 → 첫 대상 방향 광선, 폭 width, 앞에서부터 pierce마리 |
| 물수제비 skip | chain | 첫 대상에서 가장 가까운 적으로 튕김(같음) |
| 수중 underwater | circle + dot | 같음 + 장판 |
| 공중 air | random | 같음(공중 우선) |
| 강습 assault | cone | 가장 가까운 적 방향 부채꼴(angleDeg), 배 둘레에서 range 안 + coneNearPx 안은 각도 무관 |
| 충격 shock | push | **배 둘레 고리**: 배 둘레에서 range 안 전부(옆모습은 앞쪽만 = 그때 적이 모두 앞쪽이었으니 같은 뜻) |
- 밀어내기: 배에서 바깥쪽 방사 방향으로 knockback만큼. 화면 밖으로는 밀지 않는다.
- 궁극기·전설 '화면 전체' 스킬: 화면 안 적 전부, 중심점은 배 중심이다.

## E. 연결 지점 (기존 파일 — 최소 수정, 소유 레인과 맞출 것)
T1 코드는 `battle/topdown/`에 `BattleGeometry` 인터페이스로 둔다. `SideGeometry`는 지금 함수를 그대로 부르기만 하고, `TopGeometry`가 새 구현이다. 기존 파일은 '직접 부르던 것을 `field.geometry.…`로 부르기'만 바꾼다.
| 파일(소유) | 바꿀 곳 |
| --- | --- |
| `field.dart`(battle·S1) | `Field.geometry`(기본 SideGeometry), `view()`에 view 문자열·dir |
| `combat.dart`(S2) | `moveFoes` → `geometry.moveFoes(this)`, `fireGuns`의 `aimMany` → `geometry.aimMany`, `control`의 밀어내기 → `geometry.push`, `castUltimate`의 대상·중심 → `geometry.onScreen`/`center`, 분열 위치 → `geometry.splitAt` |
| `skills.dart`(battle·S1) | `aimMany`·`eligible`·화면 중심·배 위치 → geometry |
| `legend.dart`(battle·S1) | `eligible` → geometry, 끌어당김(pull)을 x만이 아니라 점 방향으로 → `geometry.pullToward` |
| `bosses.dart`(battle·S1) | summoner `spawnWave` → `geometry.spawnWave` |
| `spawner.dart`(S2) | `startBoss`의 보스·촉수 위치 → `geometry.placeBoss` |
| `battle_system.dart`(S2) | `_sync`에서 `settings.battleView`로 geometry 고르기(모드가 바뀌면 Field 새로 만들기), `spawnWave` → geometry |
- 수정량: 파일마다 2~10줄이다. 옆모습 동작은 바이트 단위로 같아야 한다(기존 시나리오·리플레이·sim 해시 그대로) → 완료 기준 1.
- 요청: 이 7곳을 S5가 한 커밋으로 고치고 **S2 검토 뒤 S1이 머지**하거나, 경로를 S5에 잠시 열어 주기. S1·S2가 정한다.

## F. 완료 기준
- T0(S2): 선택 키 JSON 왕복(키 없음 = 옛 값), 기존 세이브 픽스처·시나리오·골든 그대로.
- T1
  1. side 모드는 기존 시나리오·리플레이·`sim` 결과가 한 바이트도 다르지 않다.
  2. top 모드 단위 테스트(`test/battle/topdown/`): 사방 스폰·도착 시간(위·옆 차이 ≤ 10%), 8계열 모양별 명중, 밀어내기 방사, 보스 원 둘레 유지, 결정론(같은 시드 = 같은 결과).
  3. top 모드 sim 지표(설계서 7.2)가 side의 ±10% 안(`sim --view top`, S2와 같이), `balance crews` ±10%.
  4. 150마리 한 틱 계산 < 2ms(PC).
