# 진척: render (S3)

| 항목 | 내용 |
| --- | --- |
| 현재 계획 | `docs/plans/done/render-battle-replay.md` · 스펙 `docs/specs/render-battle-replay.md` (승인됨, S1 위임) |
| 상태 | M2 1단계(전투 기록 재생) 완료 — 골든 승인·커밋. 다음: render-perf 스펙 |
| 막힌 것 | 없음 |

## 세션 로그 (최신이 위)

### 2026-10-14 · S3 · 전투 기록 재생 구현
- 한 일:
  - 스펙 승인(S1이 사용자 위임을 전달) → 테스트 먼저(수용 기준 1~9·11) 실패 확인 → 구현.
  - 05e1e80 juice·fx_map 확장(계열 8종 발사체, support→shock 별칭, 넉백·숫자·코인·상한·lookahead).
  - fe06750 `RecordingPlayer`(보간·lookahead 2틱·히트스톱 정지·반복 + S1 요청 라이브 push 모드), `BattleScene`+`EventDirector`,
    `Pool`(고정 크기·오래된 것 회수), `DamageNumbers`(넘치면 오래된 둘 합침).
  - 8f10d56 `ScenePainter`(단색 플레이스홀더), `BattleGame(feed:, recording:, …)`, `battleFeedProvider` — S1이 main에 머지, main.dart가 `host.ticks` 연결.
  - 골든: 샘플 기록은 수치가 바뀔 때마다 재생성되므로 테스트 안 고정 기록으로 찍음(스펙과 다름, S1에 보고).
- 검증: `tool\check.bat --full` 통과(34.6s), 렌더 테스트 24개.
- 다음 할 일: 골든 승인 → 커밋 → 계획 `done/`으로 → `docs/specs/render-perf.md` 초안(실기기 fps·이펙트 수 측정, 30fps 절전).
- 남은 문제:
  - home_screen이 아직 `BattleGame()`(데모 기록) — S4가 `feed: ref.read(battleFeedProvider)`로 바꿀 예정.
  - 정수배 nearest 확대 미구현: `withFixedResolution`이 비정수 배율로 맞춘다. 화면 크기 계산을 UI와 정해야 함.
  - 절전 모드는 장면 갱신만 30fps로 줄인다(그리기는 Flame 주기 그대로).
  - 데미지 숫자 폰트는 기본 폰트(Galmuri는 아트·플랫폼 레인 에셋 등록 후). 진동은 `onHaptic` 신호만.
  - Canvas `Rect` 등 그리기 호출의 작은 할당은 남아 있음(게임 객체·컴포넌트 생성은 0).

### 2026-10-14 · S3 · 레인 시작
- 한 일: worktree `D:\Projects\pde-render`(lane/render) 진입, 레인 브리핑·계약·`juice.json`·`fx_map.json`·합성 기록 확인, 스펙+계획 초안.
  main e4edf73 머지 후 스펙을 `docs/specs/render-battle-replay.md`로 분리. S1 답변(히트스톱 프레임, 데모 기록 상수 경로) 반영.
  main 7156ca6(훅 수정)·f664a25(전투 M1) 머지.
