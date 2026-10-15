# 요청: 운영자 패널에 전장 방식(side/top) 전환 (platform S5 → S4)

- 날짜 2026-10-15 · 탑다운 전환 계획 `docs/plans/active/topdown-migration.md` T1~T3 · 계약 T0(S2 7a2663c)
- 목적: T2(렌더)·T3(UI)를 만드는 동안 사람(S1·사용자)이 실기기에서 같은 판을 옆모습과 탑다운으로 바꿔 보며 비교한다. 기본값은 계속 `side`이고, T4에서 S1이 top으로 바꾼다.

## 무엇
| # | 내용 |
| --- | --- |
| 1 | 운영자 패널(`apps/game/lib/operator/`, `kOperator` 빌드만)에 **전장 방식** 토글 하나: `옆모습` / `탑다운`. 키 `Key('op.battleView.side')`·`Key('op.battleView.top')` |
| 2 | 누르면 기존 명령 `SetSetting('battleView', 'top' \| 'side')`를 보낸다. 새 명령·계약은 없다. 엔진은 다음 틱에 전장을 그 방식으로 새로 만든다. 진행(스테이지·골드·파)은 그대로이고, 지금 떠 있는 적·보스는 새 자리로 다시 놓인다 |
| 3 | 현재 값은 `gameState.settings.battleView`로 표시(선택된 쪽 강조) |
| 4 | 세이브에 남는다(Settings 선택 키). 운영자가 아닌 빌드에서는 토글이 없고, 값이 top으로 저장돼 있어도 문제가 없게 → 아래 '주의' |
| 5 | 문구: `parts/op.*.arb` — `opBattleView`(전장 방식 / Battle view), `opBattleViewSide`(옆모습 / Side), `opBattleViewTop`(탑다운 / Top-down) |

## 주의 (T2 전까지)
- 렌더가 `BattleView.mode == 'top'`을 아직 모르면(T2 전) 탑다운 좌표(270×480, 배 중심 135,240)가 옆모습 화면에 그려져 어긋난다. 그래서 다음 둘 중 하나를 고른다(S1).
  - (a) 토글을 T2 첫 커밋(S3) 뒤에 연다.
  - (b) 지금 넣되 탑다운 쪽에 '렌더 준비 중' 표시를 붙인다.
  - 엔진 쪽은 지금 바로 동작한다(review/topdown-t1-hooks).
- 운영자 아닌 빌드에서 저장값이 top이면(운영자 빌드로 바꾼 뒤 일반 빌드로 돌아온 경우) T4 전까지는 옆모습으로 돌리는 게 안전하다.
  이것은 앱 시작 때 `SetSetting('battleView','side')`를 보내면 되는데 main.dart가 platform 몫이라 **S5가 맡는다**(필요하면 알려 주세요).

## 수용 기준 (위젯 테스트)
1. 패널을 열면 토글 2개, 지금 값(side)이 강조된다.
2. 탑다운을 누르면 명령 sink에 `SetSetting('battleView','top')` 1개가 들어온다. 옆모습도 같다.
3. `kOperator == false` 빌드 구성에서는 토글이 없다(기존 패널 게이트 그대로).
