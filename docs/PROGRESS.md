# 개발 진척

> 매 세션 **시작할 때 읽고, 끝날 때 갱신**한다(Stop 훅이 갱신 여부를 확인). 요약만 둔다 — 상세 단계는 `docs/plans/`,
> 레인 세션의 기록은 `docs/progress/<레인>.md`. 이 파일이 200줄을 넘으면 오래된 세션 로그를 `docs/progress-log/YYYY-MM.md`로 옮긴다.

## 현재 위치

| 항목 | 내용 |
| --- | --- |
| 마일스톤 | **M0 하네스 구축 — 완료** (`contracts-v1` 태그, origin: github.com/ewpark88/pirate-dot-rpg) |
| 마지막 갱신 | 2026-10-13 · S1 (단일 세션) |
| 바로 다음 할 일 | ① worktree 3개 생성 후 S2~S4 시작 ② S1은 battle 레인 M1 착수 (무리 생성부터) |
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
- [ ] 전투: 무리·발사·피해·동시 처치·보스 타이머·파밍 (`BattleSystem`)
- [ ] 강화·소환·천장·카드·승급·오프라인 (`EconomySystem`)
- [ ] `game_cli sim`이 7.2 목표 리포트, check 밸런스 스모크 활성화
- [ ] `scenarios/boss_timeout_farming.yaml` skip 해제 · 화면 없이 게임이 끝까지 돈다
- [ ] `game_cli export-events` 실제 엔진 출력

### M2 화면 연결 (S3 render · S4 ui) — 관문: 실기기 손맛 승인
- [ ] Flame 전투 화면(기록 재생 → 실제 엔진) · 타격감
- [ ] 강화·소환·원정대 탭, ko/en 골든
- [ ] 저장·복원 (SaveStore 파일 구현)
- [ ] 운영자 모드 패널
- [ ] 실기기 60fps (저사양 1대)

### M3 콘텐츠 · M4 아트·광고 · M5 AOS 출시 · M6 iOS·랭킹
- 설계서 11장 DoD 그대로. M2 관문 통과 후 항목 단위로 펼친다.

## 레인 상태

| 레인 | 세션 | 브랜치 | 상태 | 마지막 작업 | 막힌 것 |
| --- | --- | --- | --- | --- | --- |
| battle | S1 | main | 대기 (M1 첫 작업: 무리 생성) | 뼈대 `BattleSystem` | - |
| economy | S2 | lane/economy | 대기 (worktree 생성 전) | 뼈대 `EconomySystem` | - |
| render | S3 | lane/render | 대기 | 빈 `BattleGame`, 합성 전투 기록 준비됨 | - |
| ui | S4 | lane/ui | 대기 | 탭 4개 자리, 샘플 상태 4개 준비됨 | - |
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
