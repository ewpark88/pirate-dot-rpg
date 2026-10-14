# 진척: render (S3)

| 항목 | 내용 |
| --- | --- |
| 현재 계획 | `plans/active/render-regions.md`(스펙 초안, 승인 대기) · `plans/active/render-perf.md`(실기기 측정 대기) · 끝남: `render-battle-replay`, `render-m3-fx` |
| 상태 | render-regions 진행 — 배경 6종·해역 전환·보스 등장/처치(코인 비)/실패·보스 모양 구현(미커밋). 골든 2장 재승인 대기 |
| 막힌 것 | 골든 재승인(S1) · 계약 D(stage)·shielded·tier main 반영 대기 · 실기기 측정(M2 관문) |

## 실기기 측정

| 날짜 | 기기 · Android | 모드 | 10초 요약 6줄 | 판정 |
| --- | --- | --- | --- | --- |
| (대기) | | 부하 장면 | | |

## 세션 로그 (최신이 위)

### 2026-10-14 · S3 · render-regions (해역 배경·보스 연출)
- 한 일: 스펙 승인(S1)·계약 D 수용, 해역 보스·shielded·tier를 규칙 7~10으로 추가. 테스트 먼저(`regions_test.dart` 수용 기준 1~7) →
  fx_map backgrounds·bossEntrance·bossFailed·bossLook·shield·tierColors, juice bossKill.coinRain + 모델·검증,
  `Backdrop`(stage→배경, 1초 색 섞기), `StagePainter`(배경·원경 장식·보스 경고·실패 덮개), 보스 모양(`EnemyLooks.bossOf`), 코인 비.
  `scene_state.dart`로 HitState·SceneStats 분리(300줄).
- 검증: `tool\check.bat --full` 통과(29.9s).
- 다음 할 일: 골든 재승인 → 커밋 → 계약 필드 오면 stage 연결·보호막·tier·보스 골든.

### 2026-10-14 · S3 · render-m3-fx (스킬·궁극기·적 역할 연출)
- 한 일: 스펙 승인(S1)·계약 A·B·C 수용 기록. 테스트 먼저(수용 기준 1~9, 5는 계약 B 대기 skip) →
  fx_map M3 데이터(skillFxScale·screenSkill·shipSkill·ultimates 8종·enemyLook·split·revive·zone)+모델·검증,
  `M3Director`(스킬·화면 스킬 어댑터·궁극기 sweep/rain/strikes/volley·분열/부활 감지·장판 어댑터), `EnemyLooks`(regions.json 원문 role),
  이펙트 지연·이동(`Effect.delayMs/vx`), 장판 풀, 슬롯 스킬 막대·준비 깜빡임, 배 회복·버프. `scene/motion.dart`로 움직임 계산 분리.
- 검증: `tool\check.bat --full` 통과(33.5s), 렌더 테스트 47개 + skip 1.
- 추가: 골든 승인(S1) → 108a680 커밋. main(전투 M3 12abe88, 계약 A·B·C) 머지 → 어댑터 제거, `scope`·`ZoneSpawned`·`stunned`(별 2개 회전) 사용. 골든 그대로 통과.
- 다음 할 일: 해역 배경 6종 플레이스홀더 + 보스 등장·처치 연출 점검(render-regions 스펙).
- 남은 문제: 기존 골든 `battle_aoe.png`가 적 색(역할 표)·스킬 막대 때문에 바뀜 — 갱신 승인 필요.

### 2026-10-14 · S3 · render-perf (실기기 측정 준비)
- 한 일: 스펙 승인(S1)·Q1 결정(정수배는 렌더 뷰포트) 반영, 실기기 측정 절차를 복사 가능한 명령으로 스펙에 기록.
  테스트 먼저(수용 기준 1~7) → `PerfMonitor`(링 버퍼 p50·p95·최대·fps, 10초 콘솔 요약), `stressRecording()`(적 27·0.5초마다 범위 처치·히트스톱·궁극기),
  `BattleGame.loadStress/loadDemo/resumeLive`·`mode`·`perf`, 절전 `PowerSaveCache`(Picture 재사용), `integerScale`로 카메라 정수배 확대,
  측정 스위치 `--dart-define=BATTLE_SCENE=stress|demo`·`PERF_OVERLAY=true`·`POWER_SAVE=true`, 오버레이 `PerfOverlay`.
- 검증: `tool\check.bat --full` 통과(28.8s), 렌더 테스트 34개.
- 다음 할 일: 실기기 측정 결과 받기 → 표 기록 → 넘으면 원인(이펙트·숫자·그리기) 최적화 스펙.
- 남은 문제: `flutter run -d chrome` 눈 확인은 아직 안 함(위젯 테스트로만 확인). 정수배 확대는 물리 픽셀 기준이라 dpr이 소수면 논리 배율이 소수일 수 있다(정상).

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
