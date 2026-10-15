# 스펙: 탑다운 전환 T0 — 계약 (S2 구현, S5 검토 채택 2026-10-15)

- 계획: `docs/plans/active/topdown-migration.md`. T1 엔진(battle/topdown/, BattleGeometry)은 S5, 균형은 S2.
- 원칙: **모두 선택 키**. 옆모습(side) 본문·이벤트·픽스처·골든은 바이트 단위로 그대로.

## 모드 플래그
- `Settings.battleView` = `side`(기본) | `top`. `SetSetting('battleView', 'top')`. side면 세이브 본문에 쓰지 않는다(버전 그대로).

## 상태 (BattleView, EnemyView)
| 키 | 기본 | 뜻 |
| --- | --- | --- |
| `mode` | `side` | 전장 방식 |
| `shipX`, `shipY` | 없음 | 배 중심(필드 좌표). 없으면 방식의 테이블 값 |
| `shipHeading` | 0 | 배 방향(라디안, 0 = 위, 시계 방향) |
| `EnemyView.heading` | π(왼쪽) | 적 이동 방향 atan2(dy, dx) |

## 이벤트
- `AttackFired`: `fromX`, `fromY`(포구), `angle`(발사 방향) — 선택. 없으면 렌더가 배 위치에서 계산.
- `BossFired(x, y)`(ebd792c) — 보스 원거리 공격.

## 테이블 `waves.top` (TopFieldDef)
- 전장 270 × 480, 배 중심 (135, 240), 왼쪽 위 원점.
- 거리 = **배 둘레 → 적 가장자리**: dist − shipRadius(20) − 적 반경(mob 6 / boss 24) ≤ reach × reachScale(1).
- 보스 정지 bossStandoff 48(배 중심 거리) — 배·보스 반경 + 여유, 모든 계열 사거리 안(원 둘레를 돈다).
- 스폰: 테두리 바깥 spawnMargin 12. approachRadius 206 밖에서는 해류 ×approachBoost 3 — 방향에 따른 도착 시간 차이를 없앤다(옆모습 186 + 배 반경).
- 무리: 한 파를 swarmGroups 1~3 방향 묶음(±swarmSpreadDeg 20°)으로, 파 안 간격은 spawnSpacing 유지.

## 수용 기준 (topdown_contract_test)
1. Settings 기본 side·본문에 없음, top 왕복, 타입 오류 거절.
2. 옛 BattleView·EnemyView JSON → 기본값, 기본값이면 본문에 키 없음.
3. top BattleView·heading 왕복, AttackFired 선택 필드 왕복.
4. waves.top 검증 + 보스 거리가 모든 계열 사거리(최소 보정 포함) 안.

## 남은 일 (T1)
- 기존 battle 파일의 geometry 훅은 S5가 한 커밋으로(옆모습 결과 바이트 동일) → S2 검토 → S1 머지.
- 균형(S2): width 270이면 좌우 보이는 거리 135 — reach 135~172 계열이 옆으로 잘림. sim에서 첫 발사 지연 확인, 크면 ‘화면 안’ 조건을 위아래 기준으로.
