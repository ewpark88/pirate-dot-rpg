# 요청: 보스 공격력·체력 비교 표시용 공개 함수 (ui → S2, 사용자 피드백 #5)

- 요청 레인: ui (S4) · 날짜 2026-10-17 · 계획 `docs/plans/active/user-feedback-2026-10-17.md` #5
- 사용자: "보스 공격력 표시(내 공격력과 비교), 보스 체력·내 배 체력 항상 표시".
- 문제: 보스 체력·공격력은 `spawner.dart`의 `stageCurve(...) × bossHpMultiplier × def.hpMultiplier × wallBossScale …`로 정해지는데 공개 API가 없다.
  UI가 공식을 베끼면 S2가 수치를 바꿀 때마다 어긋난다(밸런스 숫자는 경제 레인 소유).

## 제안 (S2 — `game_core.dart`로 공개, 계약 변경 없음)
| # | 함수 | 반환 | 쓰는 곳 |
| --- | --- | --- | --- |
| 1 | `BossPreview bossPreview(GameState s, GameTables t, {int? stage})` | `{bossId, maxHp: BigNum, attack: BigNum, timeLimitSec, wall: bool}` — 지금(또는 [stage]) 보스. 튜토리얼 hpScale·벽 배율·모래시계 포함 | 보스 도전 버튼·보스전 게이지·패배 안내 |
| 2 | (선택) `EnemyView.hp: BigNum?` 보스만 | 지금 남은 체력 절댓값 — 보스전 '남은 1.2M' 숫자 | 보스전 게이지 |

UI 표시(예정): 보스 도전 버튼 위·보스전 게이지에 **'보스 체력 1.2M · 내 초당 공격력 80K → 약 15초 (제한 20초)'**,
**'보스 한 방 = 내 배 체력의 12%'**. 비율에 따라 초록(여유)/노랑(빠듯)/빨강(어려움) — '이길 수 있나'를 한눈에.
내 배 체력은 게이지 줄에 'HP 85%' 상시(BattleView.shipHp/shipHpMax — 이미 있음).

## 그동안 UI가 하는 것
- 내 배 체력 상시 표시(이미 있는 값)만 먼저. 보스 쪽 숫자는 함수가 오면 붙인다(가짜 값 없음).
