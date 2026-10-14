# 개발 진척

> 매 세션 **시작할 때 읽고, 끝날 때 갱신**한다(Stop 훅이 갱신 여부를 확인). 요약만 둔다 — 상세 단계는 `docs/plans/`,
> 레인 세션의 기록은 `docs/progress/<레인>.md`. 이 파일이 200줄을 넘으면 오래된 세션 로그를 `docs/progress-log/YYYY-MM.md`로 옮긴다.

## 현재 위치

| 항목 | 내용 |
| --- | --- |
| 마일스톤 | **M0 하네스 구축 — 완료** (`contracts-v1` 태그, origin: github.com/ewpark88/pirate-dot-rpg) |
| 마지막 갱신 | 2026-10-14 · S1 |
| 바로 다음 할 일 | **사람: `docs/DEVICE_TEST.md`로 M2 관문(손맛·60fps)** · S1: 레인 머지, 스테이지 40 벽(S2 성장 조정 후 같이) |
| 막힌 것 | 없음 |

## 마일스톤 체크리스트 (설계서 11장)

### M0 하네스 구축
- [x] 모노레포 뼈대 (pub workspace: game_data · game_core · game_cli · apps/game · tool)
- [x] AGENTS.md, CLAUDE.md, LANES.yaml, docs/ (ARCHITECTURE · QUALITY · lanes 6개 · ADR 6개 · 템플릿)
- [x] `tool/check.dart` + `check.bat`/`check.sh` (생성물 → 포맷 → 분석 → 의존·금지 패턴·레인 → 단위 테스트 → 시나리오 → 밸런스 스모크 → `--full` Flutter)
- [x] 의존·금지 패턴 검사: 의존 방향, 비결정성, 수치 리터럴, 하드코딩 문구, ko/en ARB, 테이블 l10n 키, 300줄, 라이선스, 운영자 가드, 레인 소유권
- [x] 일부러 규칙을 어긴 코드가 실패하는지 확인 — `tool/test/harness_test.dart` 23개
- [x] Claude Code 훅: PreToolUse(픽스처·골든 보호), PostToolUse(format+analyze, 테이블 재생성), Stop(진척 문서 + check)
- [x] `/lane-start <레인>` 명령
- [x] ~~CI 워크플로~~ → GitHub Actions 제거, 로컬 check(Stop 훅 + 커밋 전 `--full`)로 대체 (ADR-0006)
- [x] 0단계 계약 `contracts.dart`: GameState(세이브 v1과 1:1)·BattleView, Command 14 + OperatorCommand 16, GameEvent 24, 포트 7, GameEngine/GameSystem, RecordedTick
- [x] 테이블 12개 + 스키마 검증기, 선원 40명은 도트 팩 `characters.json`에서 생성
- [x] 픽스처: `fixtures/states` 4개, `fixtures/events/sample_battle.jsonl`(합성), 세이브 v1
- [x] `contracts-v1` 태그 + origin push (2026-10-13)

### M1 코어 규칙 (S1 battle · S2 economy)
- [x] BigNum (속성 테스트 포함) — 0단계에 선행
- [x] 세이브 v1 코덱·체크섬·마이그레이션 틀·백업 복구 — 0단계에 선행
- [x] 전투: 무리·발사·피해·동시 처치·궁극기(공통)·보스 타이머·파밍 (`BattleSystem`) — 경제 수치는 임시 `combat_stats`
- [ ] 강화·소환·천장·카드·승급·오프라인 (`EconomySystem`)
- [x] `game_cli sim`이 7.2 목표 리포트, check 밸런스 스모크 활성화 (목표 벗어남 4건 — economy 조정 대기)
- [x] `scenarios/boss_timeout_farming.yaml` skip 해제, `boss_clear_advances.yaml` 추가 · 화면 없이 돈다(강화가 없어 스테이지 1 파밍에서 멈춤)
- [x] `game_cli export-events` 실제 엔진 출력 (+ 앱 데모 상수 `render/demo/sample_battle.g.dart`, allLanes)

### M2 화면 연결 (S3 render · S4 ui) — 관문: 실기기 손맛 승인
- [x] Flame 전투 화면: 실제 엔진 live feed, 타격감(히트스톱·흔들림·번쩍임·넉백·숫자), M3 연출(스킬·궁극기·역할·장판·기절·보호막·해역 배경·보물상자)
- [x] 강화·소환·원정대 탭 + HUD·보스 도전·복귀 팝업·설정·순풍, ko/en, 영어 골든(전장 분리)
- [x] 저장·복원: `FileSaveStore`(save.tmp→rename, save.bak), 저장 시점 SaveRequested·10초·백그라운드, 시작 시 loadSave(백업 복구) — 통합 테스트(전투 1분→저장→복원)
- [x] 운영자 모드 패널(샘플 상태·배속·무적·보스·스테이지·자원·렌더 모드)
- [ ] **실기기 손맛 승인 + 60fps (저사양 1대) — 사람 확인 대기: `docs/DEVICE_TEST.md`** (profile APK 빌드 확인됨)

### M3 콘텐츠 (진행 중 — M2 관문 전이지만 엔진·테이블 작업은 병행)
- [x] 전투: 스킬 8계열 자동 시전·전설 화면 스킬·지원 스킬, 계열별 궁극기(밀어내기·기절·회복), 등급 사다리, 수중 장판, 적 역할 6종·해역별 적 27종 (`docs/specs/battle-m3-skills.md`)
- [ ] 해역 보스 패턴(25·50스테이지), 300 이후 등급 테두리 (`battle-m3-bosses`)
- [ ] 보물상자·순풍 버프, 환생, 일일 퀘스트·출석, 도감, 튜토리얼 (economy·ui)

### M4 아트·광고 · M5 AOS 출시 · M6 iOS·랭킹
- 설계서 11장 DoD 그대로.

## 레인 상태

| 레인 | 세션 | 브랜치 | 상태 | 마지막 작업 | 막힌 것 |
| --- | --- | --- | --- | --- | --- |
| battle | S1 | main | M1 코어 완료, export-events 남음 | `battle/` 6개 파일, 테스트 9 + 시나리오 2 | - |
| economy | S2 | lane/economy | 스펙 승인, 강화 효과 함수·UpgradePart (cf0f333) | 뼈대 `EconomySystem` | - |
| render | S3 | lane/render | 스펙 초안 `render-battle-replay` | 빈 `BattleGame`, 합성 전투 기록 준비됨 | - |
| ui | S4 | lane/ui | 스펙 `ui-tabs` 승인 대기 | 탭 4개 자리, 샘플 상태 4개 준비됨 | - |
| platform | S2 (2단계) | - | M3부터 | - | - |
| art | S3 (2단계) | - | M3부터 | - | - |

## 미결 사항 (설계서 12장) → ADR

| 항목 | 상태 |
| --- | --- |
| 게임 이름·패키지 ID | 임시 `repo.dot.pirate` (ADR-0002), M5 전 확정 |
| 화면 방향·태블릿 | 미정 (세로 고정 가정) |
| 최소 지원 OS | 미정 (Android 7.0 / iOS 13 제안) |
| 환생 해금 스테이지 | 테이블은 40 (설계서 본문), 미결 목록은 30 제안 — 밸런스 시뮬 후 확정 |
| 보스 재도전 광고 버프 | 테이블에 `bossSupport` 있음, 채택 여부 미정 |
| Apple 가입 시점 | Android 지표 확인 후 |

## 새 세션 시작 방법

```bat
rem S1 (이 폴더, main)
cd /d D:\Projects\pirate-dot-rpg & claude          → /lane-start main

rem contracts-v1 태그 뒤 한 번만
git worktree add ..\pde-economy -b lane/economy
git worktree add ..\pde-render  -b lane/render
git worktree add ..\pde-ui      -b lane/ui
rem 각 worktree에서 처음 한 번: flutter pub get

title S2-economy & cd /d D:\Projects\pde-economy & claude   → /lane-start economy
title S3-render  & cd /d D:\Projects\pde-render  & claude   → /lane-start render
title S4-ui      & cd /d D:\Projects\pde-ui      & claude   → /lane-start ui
```

## 세션 로그 (최신이 위)

### 2026-10-14 · S1 · 저장·복원, 전투 M3, 레인 지휘
- 한 일: 저장·복원(FileSaveStore·자동 저장·pause/resume으로 savedAt 보정), 운영자 패널·ui 탭·렌더 perf 머지, 세이브 v2(ADR-0007).
  전투 M3 스펙(S1 승인, 사용자 위임) → 테스트 먼저 11개 → 구현(skills.dart·Zone·역할·사다리), 계약 추가: SkillCast.scope, EnemyView.stunned, ZoneSpawned(렌더 요청 A·B·C).
  sim 재조정: 스킬 multiplier 1.0→0.5, boss.hpMultiplier 8→16, travelSec 2→3 → 첫 보스 실패 1.02분·스테이지 10 10.6분(OK), 가장 긴 벽 4.5분.
- 다음 할 일: S2 offlinePreview·무료 10연 머지(UI 픽스처 summon.total 수정 선행), S3 M3 연출·S4 core-loop 골든 승인·머지, 스테이지 40 벽 설계(S2와 분담)

### 2026-10-14 · S1 · 전투 M1 코어 + 레인 지원
- 한 일:
  - 스펙 승인(8번째 계열 = `shock`, 쿡·램프만 선원별 스킬 `support_rally`; 골드·젬은 전투가 지갑에 직접).
  - 테이블: skills(`shock`, `crewSkills`, 발사 간격·배율·제외 층), waves(`field`, `boss.speed`, `multiKill.hitStopMinKills`), crews(`skill`), meta(`startingCrews`).
  - `battle/`: `field`(내부 시뮬 상태 ↔ BattleView), `spawner`, `targeting`(모양 8종), `combat`(발사·피해·처치·동시 처치·궁극기·접촉), `fleet`, `combat_stats`(임시), `battle_system`.
  - `engine/units.dart`: 단위 상수(half·도→라디안·ms→초) — battle/의 숫자 리터럴 0 유지.
  - 테스트 `test/battle/battle_test.dart` 9개, 시나리오 boss_timeout_farming(skip 해제)·boss_clear_advances.
  - 레인 세션 3개에 작업 배정(e4=economy, 43=render, de=ui). 레인 보고로 고친 하네스 버그: 레인이 `docs/specs/<레인>-` 소유(e4edf73),
    훅이 worktree 세션의 실제 저장소를 검사(7a4df03), git status 첫 줄 경로 잘림(136244a).
- 실수: 7a4df03에 포맷 안 된 pre_edit.dart를 커밋해 레인 check가 깨짐(7156ca6 수정). shared 커밋 전에는 check를 먼저 돌린다.
  전투 테스트를 구현 뒤에 썼다(계획의 순서 위반).
- 발견: 새 게임에 선원이 0명이라 전투가 안 돌았다 → `meta.startingCrews`(옥토·톡). 첫 보스 실패 약 1분 40초(목표 1~3분).
- 추가: lane/economy(735a528) main 머지, `combat_stats`를 경제의 `ShipStats.of`·`crewPowerMultiplier`로 교체, 경제 함수를 `game_core.dart`로 export(UI용).
  render·ui 스펙은 S1이 승인(사용자 위임) — 레인 세션은 자기 사용자에게 위임 확인 후 시작.
- 추가2: economy 99445f3 머지(합치기·승급·보스 카드·오프라인), 보스 처치에 `grantBossCards`+`SaveRequested` 연결, offline.dart export.
- 추가3: lane/ui 3f6fa8c 1차 머지(HUD·배 탭). 앱에 엔진 연결: `apps/game/lib/engine_host.dart`(20Hz, 배속, RecordedTick 스트림), main.dart가 ProviderScope override로 상태·명령 통로를 꽂는다(ui 파일 무변경). 세이브 불러오기는 platform(TODO).
- 추가4: economy 운영자 명령·`game_cli sim` 머지(check 밸런스 스모크 활성). 전투 테이블 조정(sim 20명×3시간):
  `hpBase` 20→10, `hpGrowth` 1.16→1.19 → 스테이지 10: 18.7→7.6분(OK), 처음 10분 한 파 33→9.4초, 첫 보스 실패 1.3분(OK), 가장 긴 벽 1.5분.
  스테이지 40은 0.4시간(목표 1.5~3시간) — hpGrowth로는 거의 안 변함, 첫 전설 0.08일 등 경제 성장 속도가 결정 → economy(사용자 결정 대기).
  boss_timeout_farming 시나리오는 op.setFleet[octo]로 약한 편성 고정.
- 추가5: lane/render 8f10d56 머지(재생기·연출·풀/상한·라이브 feed), main.dart가 `battleFeedProvider`에 `EngineHost.ticks` 연결.
  `game_cli fixtures`가 운영자 패널용 `apps/game/lib/operator/sample_states.g.dart` 생성(allLanes).
  lane/ui 586b804 머지는 --full 실패(UI 골든에 전장 그림이 찍혀 렌더 변경에 깨짐)로 push 전 머지 커밋을 버림 → UI 골든은 HUD·탭만 찍기로(S4 수정 중).
- 추가6: 사용자 결정 4건(오프라인 효율 계수, 옥토 카드 14장, 광고 30젬, 스테이지 40 = 플레이 시간) → 설계서 4.3.3·4.6·4.7·7.2 반영, S2에 전달.
  세이브 v2(`summonsTotal`, ADR-0007, 픽스처 v2.json). render 골든·render-perf 스펙(승인), ui 소환·선원 탭·골든(전장 분리)·live feed·운영자 패널 스펙(승인) 머지 → 앱 전장이 실제 엔진으로 돈다.
- 다음 할 일: economy 밸런스·무료 10연, ui 운영자 패널, render-perf 머지 → M2 관문(실기기 손맛·60fps)은 사람 확인
- 남은 문제: 한 파 약 30초로 느림(sim으로 조정), 스킬·장판·기절·적 역할은 M3, 보스 카드는 경제 레인

### 2026-10-14 · S1 · worktree 생성, 전투 스펙 초안
- 한 일: worktree 3개(`pde-economy`·`pde-render`·`pde-ui`, 브랜치 `lane/*`, `dc021c4` 기준) 생성, 각각 `flutter pub get`, economy에서 check 통과.
  전투 M1 스펙 초안 작성 — 수용 기준 11개, 내부 시뮬 상태는 `BattleSystem` 인스턴스가 들고 BattleView로 투영(계약 변경 없음).
- 발견: `skills.json` 8번째 계열이 `support`인데 설계서는 `shock`; 계열별 발사 간격이 테이블에 없음; `rarities.json` 소환 확률이 설계서와 다름.
- 다음 할 일: 스펙 승인 → `docs/plans/active/battle-m1-core.md` → 테스트 먼저

### 2026-10-13 · S1 · GitHub Actions 제거
- 한 일: 사용자 결정으로 `.github/workflows/`(ci·nightly)를 삭제하고 ADR-0006을 썼다. 검증은 Stop 훅과 커밋 전 `tool\check.bat --full`로 한다.
  AGENTS.md, platform 레인 문서, LANES.yaml(platform의 `.github/`), QUALITY, check 주석에서 CI 언급을 정리했다.
- 실수 기록: CI 결과를 보려고 인증 없이 GitHub API를 15초마다 조회해서 시간당 60회 한도를 다 썼다.
  git push와는 관계없다. 앞으로 원격 상태를 반복 폴링하지 않는다.
- 다음 할 일: worktree 3개 생성 → S2~S4 시작

### 2026-10-13 · S1 · 원격 연결과 CI 수정
- 한 일: origin(`https://github.com/ewpark88/pirate-dot-rpg`) 연결, 첫 커밋 + `contracts-v1` 태그 push.
  첫 CI가 `flutter pub get`에서 실패 — `apps/game/lib/l10n/merged/`가 gitignore라 새 clone에 없어 `generate: true`의 gen-l10n이 실패.
  → merged ARB를 커밋하는 생성물로 전환(`allLanes`에 추가), check가 최신 여부 검사, ARB 조각 수정 시 PostToolUse 훅이 자동 병합. 새 clone에서 pub get 성공 재현.
  2차 CI는 `tool/check.sh`가 실행 권한 없이(100644) 커밋되어 실패 → `git update-index --chmod=+x`로 수정 (Windows git은 core.filemode=false라 chmod가 기록되지 않음).
- 다음 할 일: (위 항목으로 대체)

### 2026-10-13 · S1 · M0 하네스 + 0단계 계약
- 한 일:
  - 설계서를 `docs/GAME_DESIGN.md`로 옮기고 모노레포·하네스·계약·픽스처·문서 전체 구성 (계획: `docs/plans/done/2026-10-13-m0-harness.md`)
  - Flutter 앱 생성(android/ios, `repo.dot.pirate`), Flame 1.38.2 · Riverpod 3.4 · gen-l10n(ko/en)
  - BigNum 속성 테스트가 `math.pow(10, int)` 정수 오버플로 버그를 잡아 수정
- 검증:
  - `tool\check.bat --full` 통과 (약 18초, 목표 90초) — 단위 테스트: game_data 8 · game_core 40 · game_cli 3 · tool 23, 위젯 2
  - 실제 저장소에 위반 파일(코어에 flutter import·DateTime.now·숫자 리터럴)을 넣으면 check가 4건 모두 고칠 방법과 함께 실패
  - 훅: 세이브 픽스처 수정 차단(exit 2), 진척 문서 미갱신 시 Stop 차단 확인
  - `flutter build apk --debug` 성공, 패키지 `repo.dot.pirate` 확인 · `game_cli save inspect` 정상
- 다음 할 일: 위 “현재 위치”의 ①②③
- 남은 문제:
  - `waves.json` 몬스터 곡선, `growth.json` 승급 골드는 임시값 (경제 레인 시뮬로 확정)
  - 스토어 빌드 운영자 코드 잔존 검사는 소스 가드 검사만 있음 — 빌드 산출물 검사는 플랫폼 레인(M4)
