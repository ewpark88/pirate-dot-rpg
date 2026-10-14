# 진척: ui 레인 (S4)

## 현재 위치
| 항목 | 내용 |
| --- | --- |
| 계획 | `docs/plans/active/ui-tabs.md` — 하단 탭 1차(배·소환·선원) + 상단 HUD |
| 상태 | 스펙 초안 작성, 사람 승인 대기 |
| 기다리는 것 | S2 경제 함수(강화 효과·비용, 승급·소환 비용), main의 `battleFamilyShock` 머지 |

## 세션 로그 (최신이 위)

### 2026-10-14 · S4 · 레인 시작
- 한 일: worktree `D:\Projects\pde-ui`(lane/ui, main과 같은 커밋) 진입, 레인 브리핑·계약·테이블 확인, 스펙+계획 초안 작성.
- 다음 할 일: 스펙 승인 → 상태 구독(`gameStateProvider`, `CommandSink`) 테스트부터.
- 남은 문제: 소환 확률은 설계서(65/27/7/1)가 기준 — `rarities.json` 수정은 S2 몫(S1 확인), UI는 테이블 그대로 표시.
- main e4edf73 머지(레인이 `docs/specs/<레인>-` 소유) → 스펙을 `docs/specs/ui-tabs.md`로 분리.
