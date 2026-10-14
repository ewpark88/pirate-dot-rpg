# 진척: render (S3)

| 항목 | 내용 |
| --- | --- |
| 현재 계획 | `plans/active/render-balance-crews.md`(구현 완료, 결과 S1 검토) · `plans/active/render-perf.md`(실기기 측정 대기) · `plans/active/render-audio.md`(음원·어댑터 대기) |
| 상태 | 원뿔 버그 수정(main f897484) 뒤 balance crews 재측정 — 강습만 크게 벗어남(×3.4~6.0), 조합 ×2.245 |
| 막힌 것 | 강습 수치 재조정(S1) · 렌더 외부 대기(승급 그림·음원·실기기 측정) |

## 실기기 측정

| 날짜 | 기기 · Android | 모드 | 10초 요약 6줄 | 판정 |
| --- | --- | --- | --- | --- |
| (대기) | | 부하 장면 | | |

## 세션 로그 (최신이 위)

### 2026-10-14 · S3 · sim 전설·신화 시점 점검 (②)
- 임시 조사(커밋 안 함): `SimPlayer`(시드 1, 연속 접속)를 1시간씩 12시간 돌리며 함대 선원의 레벨별 단독 점수 ÷ 같은 레벨 40명 중앙값.
  전설(L46~)·신화(L61~)가 들어오는 시점 모두 1.00 — 단 충격(turtle)은 단독 피해만 보면 0.14~0.28.
  실제 점수표(지원 환산 포함)로 레벨 47·54·63을 돌리면 모두 ✓(turtle 1.006~1.013) → 균형표와 sim 레벨은 맞는다.
- 발견: 충격 점수의 약 82%가 배 보호분(κ×막은 배 피해)이고 자기 피해는 중앙값의 15%쯤. sim 함대에 turtle이 처음부터 있어
  진행 속도(피해량)는 균형표 기대보다 느릴 수 있다. L63에서 파트너 증가분이 음수(−527, 밀어내기가 직사 대상을 멀리 보냄).
- 참고(경제): 연속 접속 sim에서 첫 신화 8시간째(L61), 12시간째 신화 5명.

### 2026-10-14 · S3 · 실기기 설치 (사용자 확인용)
- lane/render(main f897484 + 렌더 ad020be) profile 빌드 `--dart-define=OPERATOR=true` → Galaxy S24(SM-S921N, Android 16) 설치·실행 확인(프로세스 살아 있음, FATAL 로그 없음).
  화면: 전장 정수배 확대 + 둘레 여백, 배(ship_t1)·초상 스프라이트, 산호초 배경. 사용자 손맛 확인 대기.

### 2026-10-14 · S3 · 원뿔 수정 뒤 재측정
- main f897484(coneNearPx 16) 머지 → `balance crews` 전체(37.5초): 강습 외 계열 평균 1.00(충격 1.01~1.13), 밖 27칸 중 강습 22·충격 5(75레벨 4, 60레벨 lamp).
  강습 레벨별 평균 15: 6.04, 30: 5.60, 45: 5.44, 60: 3.77, 75: 3.36 — 무리전 A가 중앙값의 6~9배, 보스전 B 1.3~1.4배(45 이하). 전설(60·75)은 선원마다 갈림.
  조합 상위 1% ×2.245(실패, 상위 조합 모두 강습 2명). 결과 표 `plans/active/render-balance-crews-report.md` 갱신. 수치 조정은 S1.

### 2026-10-14 · S3 · 조합 시너지 조사
- 한 일: main 897938c(1차 조정) 머지, balance 테스트 통과. 레벨 45 조합 상위 1% ×1.655 재현. 임시 조사(커밋 안 함)로 조합 안 선원별 피해 ÷ 단독 피해:
  강습(crabby)만 무리전 ×5~7, 충격 선원(cook·turtle 둘 다)과 함께일 때. 보스전은 시너지 없음. 지원 버프와 무관.
- 원인: 배에 닿은 적은 `x = shipX`에 멈춤 → cone 각도 `atan2(|dy|, max(dx,0))`이 90° → 원뿔 밖. 충격이 밀어내면 dx>0이 되어 강습이 다시 맞힘.
  조합 점수는 함대 Damage 합만 쓰므로 이중 계산 아님. 수정 제안(근접 거리 규칙 coneNearPx)을 S1에 전달 — battle 레인.
- 다음 할 일: S1 수정 뒤 `balance crews` 재측정·보고.

### 2026-10-14 · S3 · balance crews 구현
- 한 일: 스펙 승인(Q1 (b) 선체 레벨로 실제 ShipDamaged, Q2 κ 0.5, Q3 시간 보고). 테스트 먼저(`packages/game_cli/test/balance/` 9개) →
  `lib/src/balance/arena.dart`(엔진 한 판, 처치·침몰이면 MeasureError, S_tank 25 배수 거절), `crew_scores.dart`(레벨별 중앙값 ±10%, 지원 환산), `combos.dart`(같은 계열 2명 이하 6명),
  `report.dart`(마크다운), `commands/balance.dart` crews(옵션·JSON·종료 코드 0/1/2).
- 결과(`plans/active/render-balance-crews-report.md`): 실패. 중앙값 대비 계열별 — 투척 1.77(15)→0.62~0.87(75), 수중 1.3~1.4(초중반), 관통 1.17~1.37,
  공중 0.67~0.84, 충격 0.47~0.93(지원 환산 포함), 강습 0.13~0.25(보스전 0: 사거리 40px라 보스가 30초 안에 닿지 않음 — 실제 게임과 같음).
  레벨 60·75부터 같은 계열 안에서도 갈림(전설 능력). 조합 상위 1% ×1.267(한도 1.3) 통과.
- 측정 시간: `--quick` 4.3초, 전체 28.6초.

### 2026-10-14 · S3 · balance crews 스펙 초안
- 한 일: main 8f6bf78 머지(LANES: balance.dart·lib/src/balance/·test/balance/를 render로). 설계서 4.8·운영자 명령·엔진 경로 조사 →
  `docs/specs/render-balance-crews.md` 초안: 단단한 스테이지(2001, 일반 보스)에서 Damage 합, A 무리전 12마리 60초, B 보스 제한 시간 피해 ×(60/제한),
  점수 (A+B)/2, 레벨 15~75 중앙값 ±10%, 지원 환산(파트너 증가분 + κ×배 보호분), 같은 계열 2명 이하 6명 조합 N개 상위 1% ≤ 중앙값×1.3, 마크다운+JSON, 종료 코드.
- 발견: 무적이면 엔진이 `ShipDamaged`를 안 낸다 → 배 보호분 측정 방법을 Q1로 S1에 질문.

### 2026-10-14 · S3 · 최적화 조사
- 한 일: 골든 2장 승인 → 44783d4(머지 해시 S1에 전달). 임시 측정(커밋 안 함): 부하 장면 60초·실제 엔진 120초에서 풀 상한 도달 0%,
  최고 이펙트 34/40·숫자 17/24·코인 40/60. 스프라이트 그리기 평균 71번/프레임이 이미지 약 11장으로 묶임 → drawAtlas 후보(필터 쓰는 적은 따로).
  결과·후보 3개를 `plans/active/render-perf.md`에 기록. 코드 변경은 실기기 측정 뒤.

### 2026-10-14 · S3 · '큰 순간' 연출
- 한 일: render-moments 승인, 계약 G 거절(배 등급은 stage 파생) → 요청서에 결과 기록. `Backdrop`을 `regions.regionAt(stage)`로 바꿔 무한 항해 반복 반영(stage 400 → 폭풍해).
  테스트 먼저(`moments_test.dart` 7개) → `Moments`(해역 보스 = regionAt(stage).regionBoss 첫 등장 컷인 1.2초·세션당 1번, 배 등급 = shipTiers.tierAt(stage)·바뀌면 빛기둥+level_up,
  ShipTierUp과 중복 1번, 해역 이동 해일 sweep), `ShipPainter`(등급 스프라이트 `ship:<tierId>`·플레이스홀더 shipLook·빛기둥), 컷인 띠(StagePainter).
- 검증: `tool\check.bat --full` 통과. 골든 `battle_cutin.png` 새로, `battle_boss_storm.png`는 stage 75 배가 sloop가 되어 갱신(미커밋).

### 2026-10-14 · S3 · 적 상태 표시
- 한 일: render-status 승인·계약 F(main 286c687) → 테스트 먼저(`status_test.dart` 4개, 픽셀 확인) → `StatusPainter`(감속 색조·물방울, 화상 불꽃 깜빡임(번쩍임 끄기면 고정), 취약 화살표,
  기절 별까지 머리 위 한 줄 가운데 정렬), 스프라이트 감속 필터. fx_map `status`. render_tables는 설정 묶음을 캐시 getter로 바꿔 284줄.
- 검증: `tool\check.bat --full` 통과, 렌더 테스트 78개. 골든 `battle_status.png` S1 승인 → 7cb5af9, 계획 done/.
- 추가: main 4d480ff(순풍 중 speed 2) 머지, 라이브 speed 2 소비 테스트 추가(버퍼·지연 정상). '큰 순간' 스펙 `render-moments` + 계약 요청 G(BattleView.shipTierId) 초안.

### 2026-10-14 · S3 · 사운드 연결
- 한 일: 골든 `battle_sprites.png` 승인·커밋(d3c03e1). render-audio 승인·계약 E(AudioPort, main 5b8ef89) → 테스트 먼저(`audio_test.dart` 5개) →
  `SoundDirector`(이벤트→fx_map sfx, 타격음 변형·피치 결정론, 같은 id 40ms·프레임당 6개 상한, 해역 bgm), `Backdrop.bgmFor`, `BattleGame(audio:)`·`audioLog`.
- 검증: `tool\check.bat --full` 통과, 렌더 테스트 74개.
- 남은 문제: 어댑터(adapters/, flame_audio)·pubspec 의존은 S1/플랫폼. 음원은 사람이 고른 뒤.
- 추가: 아트 팩 계획 done/. 전설 능력(main 19aa020)의 감속·화상·취약 표시용 계약 요청 F + `render-status` 스펙 초안.

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
