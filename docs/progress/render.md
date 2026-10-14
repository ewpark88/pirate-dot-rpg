# 진척: render (S3)

| 항목 | 내용 |
| --- | --- |
| 현재 계획 | `docs/plans/active/render-battle-replay.md` · 스펙 `docs/specs/render-battle-replay.md` |
| 상태 | 스펙 초안 작성, 사람 승인 대기 |
| 막힌 것 | 스펙 승인 (S1 질문 Q1·Q2는 해결) |

## 세션 로그 (최신이 위)

### 2026-10-14 · S3 · 레인 시작
- 한 일: worktree `D:\Projects\pde-render`(lane/render, main과 같은 dc021c4) 진입, 레인 브리핑·계약(BattleView·GameEvent·RecordedTick)·
  `juice.json`·`fx_map.json`·합성 기록 확인. S1 공지(좌표·층 기준 y·발사체 비행 없음·support→shock) 반영해 스펙+계획 초안 작성.
- 추가: main e4edf73(레인이 `docs/specs/<레인>-` 소유) fast-forward 머지, 스펙을 `docs/specs/render-battle-replay.md`로 분리.
  S1 답변 반영 — 히트스톱 중 같은 위치 프레임이 `hitStopTicks` 감소하며 연속, 데모 기록은 `render/demo/sample_battle.g.dart` 상수.
- main 7156ca6까지 머지(훅 경로 수정 + pre_edit.dart 포맷 수정). `tool\check` 통과(20.6s).
- main f664a25(전투 M1 코어) 머지, check 통과. 합성 기록 재생성(이벤트 구성은 그대로). 실제 엔진 특성(12px 줄, 화면 밖 생성, 조준점 의미)을 스펙 결정 기록에 추가.
- 다음 할 일: 스펙 승인 → 테스트 먼저(수용 기준 1~9) → `RecordingPlayer`
- 남은 문제: `docs/specs/`가 shared라 스펙을 계획 파일에 둠. 합성 기록은 옛 y 좌표·hitStopTicks 0뿐.
