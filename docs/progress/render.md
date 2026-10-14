# 진척: render (S3)

| 항목 | 내용 |
| --- | --- |
| 현재 계획 | `plans/active/render-audio.md`(음원·어댑터 대기) · `plans/active/render-art-pack-v02.md`(완료 직전) · `plans/active/render-perf.md`(실기기 측정 대기) |
| 상태 | 스프라이트 골든 d3c03e1. 사운드 연결(SoundDirector·BattleGame(audio:)) 구현, 렌더 테스트 74개 |
| 막힌 것 | CC0 음원 선정(사람, M4) · flame_audio 어댑터(platform 경로, S1) · 실기기 측정(M2 관문) |

## 실기기 측정

| 날짜 | 기기 · Android | 모드 | 10초 요약 6줄 | 판정 |
| --- | --- | --- | --- | --- |
| (대기) | | 부하 장면 | | |

## 세션 로그 (최신이 위)

### 2026-10-14 · S3 · 사운드 연결
- 한 일: 골든 `battle_sprites.png` 승인·커밋(d3c03e1). render-audio 승인·계약 E(AudioPort, main 5b8ef89) → 테스트 먼저(`audio_test.dart` 5개) →
  `SoundDirector`(이벤트→fx_map sfx, 타격음 변형·피치 결정론, 같은 id 40ms·프레임당 6개 상한, 해역 bgm), `Backdrop.bgmFor`, `BattleGame(audio:)`·`audioLog`.
- 검증: `tool\check.bat --full` 통과, 렌더 테스트 74개.
- 남은 문제: 어댑터(adapters/, flame_audio)·pubspec 의존은 S1/플랫폼. 음원은 사람이 고른 뒤.

### 2026-10-14 · S3 · 아트 팩 v0.2 적용
- 한 일: S1 결정(Q1 render가 assets·tools/art 소유, Q2 pubspec은 S1 머지 때). `tools/art/import_pack.py`(zip 이미지·json만 읽음, 크기 검증, overrides 우선,
  LICENSES.json 자동, `--check` 재실행 동일) + 테스트 3개 → 에셋 62개(초상 40·fx 8·적 6·보스선·배·발사체 5·코인) 11f3c8c.
  렌더: `SpriteBank`·`SpriteDraw`(nearest·흰 번쩍임·물속 색조), `HudPainter` 분리, `BattleGame.loadSprites/useSprites/spriteCount` 4d537e1.
- 검증: `tool\check.bat --full` 통과(42.3s), 렌더 테스트 67개, `python -I tools/art/test_import_pack.py` OK.
- 커버리지: 적 27종 중 6, 보스 14 중 1(enemy_ship), 발사체 8 중 5(shock·assault·air 없음), 해역 배경 0/6 — 나머지는 플레이스홀더.
- 추가: main(pubspec assets 7개) 머지 → SpriteBank가 AssetManifest에 있는 것만 읽게 수정(없는 종류 읽기 오류 제거) 0b16bdb.
  부하 장면 그리기 비용(테스트 환경·소프트웨어 래스터, 600프레임): 플레이스홀더 record 0.238ms·raster 0.614ms → 스프라이트 record 0.212ms·raster 0.811ms.
  실제 이미지 골든 `battle_sprites.png` 생성(S1 확인 대기, 미커밋). 사운드 스펙 `render-audio` + 계약 요청 E(AudioPort) 초안.
- 다음 할 일: 골든 승인 → 커밋 → render-audio 승인 후 테스트 먼저.

### 2026-10-14 · S3 · M2 관문 준비 + 아트 팩 스펙
- 한 일: 보스 골든 커밋(7bc4922, storm_pirate·deep_sub 색 밝게). `live_engine_test.dart` — EngineHost(실제 엔진) 30초를 60Hz로 라이브 재생:
  적 등장·처치·버퍼 64틱 미만·fps 60·오버레이 숫자·콘솔 `[perf]` 요약이 live에서도 나옴(ab11e7d). 앱은 `battle_providers.dart`가 `battleFeedProvider`로 연결돼 있음.
  아트 팩 v0.2 스펙 초안 `docs/specs/render-art-pack-v02.md`(에셋 배치·import_pack.py·LICENSES OWN 규칙·SpriteBank·pubspec 요청).
- 남은 문제: `flutter run -d chrome` 눈 확인은 아직(테스트로만). art 경로는 lane/render에서 쓸 수 없음 → Q1.

### 2026-10-14 · S3 · render-regions (해역 배경·보스 연출)
- 한 일: 스펙 승인(S1)·계약 D 수용, 해역 보스·shielded·tier를 규칙 7~10으로 추가. 테스트 먼저(`regions_test.dart` 수용 기준 1~7) →
  fx_map backgrounds·bossEntrance·bossFailed·bossLook·shield·tierColors, juice bossKill.coinRain + 모델·검증,
  `Backdrop`(stage→배경, 1초 색 섞기), `StagePainter`(배경·원경 장식·보스 경고·실패 덮개), 보스 모양(`EnemyLooks.bossOf`), 코인 비.
  `scene_state.dart`로 HitState·SceneStats 분리(300줄).
- 검증: `tool\check.bat --full` 통과(29.9s).
- 추가: 골든 재승인 → d640aad. main(해역 보스) 머지 → 보호막 테두리·깨짐·tier 테두리 2e9ccae, 렌더 테스트 58개.
- 추가: main(16dda02 stage·chest) 머지 → b78d0fe 프레임 stage로 배경, 보물상자(둥둥·가라앉기·흐려짐). 렌더 테스트 62개.
- 추가: 보스 골든 승인(S1) — storm_pirate #8E3B2E·deep_sub #D4AC0D로 밝게(바다와 겹침) 후 커밋, 계획 done/.
- 다음 할 일: live 모드 실기기 확인 준비(PERF_OVERLAY live), art-pack-v02 스펙 초안.

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
