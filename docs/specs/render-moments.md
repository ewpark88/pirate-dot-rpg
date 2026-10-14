# 스펙: 렌더 — '큰 순간' 연출 (해역 보스 첫 등장 컷인 · 배 등급 승급 · 해역 이동)

- 상태: 승인됨 (2026-10-14, S1) · 레인: render(S3) · 설계서 절: 4.4 보스 처치 연출, 4.2 배 강화(등급), 4.11 해역
- 계약 요청: `docs/contracts/requests/render-ship-tier.md` (BattleView.shipTierId) — **거절, stage에서 파생**

## 목적
- 시원한가: 오래 키운 보상(해역 보스 조우, 배 승급, 새 해역)이 화면에서 "사건"으로 느껴지게 한다.
- 피로가 없는가: 컷인은 해역 보스 **첫 등장**에만(세션당 종류별 1번), 1.2초 안. 전투는 멈추지 않는다(연출만).
- 공정한가: 연출 중에도 시뮬·기록은 그대로(히트스톱·슬로모션 추가 없음).

## 규칙
1. **해역 보스 판정**: `BossSpawned.kind == tables.regions.regionAt(frame.stage).regionBoss`면 해역 보스(무한 항해 반복 포함).
2. **첫 등장 컷인**(`fx_map.cutIn`): 전장 가운데 어두운 띠(높이 40px)가 오른쪽에서 밀려 들어와(`inMs` 300) 머무르고(`holdMs` 600) 왼쪽으로 빠진다(`outMs` 300).
   띠 안에 보스 모양(스프라이트 또는 bossLook 사각, 2배)과 위·아래 붉은 선. 이름 문구는 UI가 `BattleGame.cutIn`(kind·진행률)을 보고 얹는다.
   같은 kind는 이 `BattleGame`이 살아 있는 동안 한 번만(다시 만나면 기존 등장 경고만). 번쩍임 끄기여도 띠는 보인다(깜빡임 없음).
3. **배 등급 승급**(`ShipTierUp(tierId)`): 배 위로 빛기둥(폭 20px, 화면 위→배, `pillarMs` 900, 알파 펄스) + `level_up` 시트 2배 + 배 흰 번쩍임.
   배 그림은 `ship_tiers.json tiers[].sprite`(ship_t1~t4) — 스프라이트가 없으면 플레이스홀더 배 색·크기를 등급별로(`fx_map.shipLook[tierId]`).
4. **지금 등급**: 매 프레임 `tables.shipTiers.tierAt(frame.stage)`로 구한다(첫 프레임부터 맞는 배). 등급이 바뀌는 순간과 `ShipTierUp`은 같은 연출 한 번.
5. **해역 이동**: 배경이 다른 해역으로 바뀌는 순간 해일 시트가 화면을 한 번 쓸고(궁극기 sweep 재사용, 피해 숫자 없음) 배경 색 섞기가 그 뒤를 따른다.
   해역 이름 배너는 UI(`battleRegion*` 키).
6. **수치**: `fx_map.json`(`cutIn`, `pillar`, `shipLook`, `regionSweep`).

## 수용 기준 — `apps/game/test/render/`
1. Given 해역 보스 `BossSpawned` When 재생 Then 컷인이 켜지고 `inMs+holdMs+outMs` 뒤 꺼진다. 같은 kind 두 번째는 컷인 없음. 중간 보스·일반 보스는 컷인 없음.
2. Given 컷인 중 When 시간이 흐름 Then 재생 위치는 컷인 없을 때와 같다(전투가 멈추지 않음).
3. Given stage 29→30(+같은 틱 `ShipTierUp('sloop')`) When 재생 Then 빛기둥이 한 번 `pillarMs` 동안 보이고, 배 모양이 sloop(스프라이트 `ship_t2` 또는 `shipLook.sloop`)으로 바뀐다.
4. Given 첫 프레임 stage 80 When 그림 Then 처음부터 warship 모양, 빛기둥 없음.
5. Given 해역 50→51 When 재생 Then 해일 sweep 이펙트 1번, 피해 숫자 없음.
6. 골든 1장: 해역 보스 컷인 중간(`goldens/battle_cutin.png`, 승인 필요).

## 문구
없음 — 보스 이름·해역 이름·승급 문구는 UI가 `BattleGame.cutIn`·이벤트를 보고 띄운다.

## 운영자 모드
S1 운영자 명령(해역 보스 소환·배 등급 올리기·스테이지 이동)으로 바로 확인. `BattleGame.resetSeenBosses()`로 컷인 다시 보기.

## 결정 기록 (2026-10-14, S1)
- 계약 G 거절: 배 등급·해역 보스는 stage에서 파생(규칙 1·4). 해역 배경도 같은 이유로 `regions.regionAt(stage)`를 쓴다(무한 항해 반복 반영 — render-regions의 `Backdrop`을 이에 맞춰 고침).
- 승급 그림 ship_t2~t4는 아트 대기(M4 사용자 확인 목록).
