# 개발 진척

> 매 세션 **시작할 때 읽고, 끝날 때 갱신**한다(Stop 훅이 갱신 여부를 확인). 요약만 둔다 — 상세 단계는 `docs/plans/`,
> 레인 세션의 기록은 `docs/progress/<레인>.md`. 이 파일이 200줄을 넘으면 오래된 세션 로그를 `docs/progress-log/YYYY-MM.md`로 옮긴다.

## 현재 위치

| 항목 | 내용 |
| --- | --- |
| 마일스톤 | **M0 하네스 구축 — 완료** (`contracts-v1` 태그, origin: github.com/ewpark88/pirate-dot-rpg) |
| 마지막 갱신 | 2026-10-17 · S1 |
| 바로 다음 할 일 | **사용자 피드백 21건(docs/plans/active/user-feedback-2026-10-17.md)** P0: 1분 희귀 연사 선원·피버 200→1000·가이드 v2·패배 안내·초반 핵앤슬래시·보스/카드/상자 보상 연출 → P1 정보 표시 → P2 다듬기. 폰 연결 시 설치·발열 측정 |
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
- [x] 해역 보스 패턴(25·50스테이지), 300 이후 등급 테두리 (`battle-m3-bosses`), 튜토리얼 3단계 보스
- [x] 선원별 전설 고유 능력·신화 강화 40명 (`battle-m3-legend`, 효과 부품 9개)
- [~] 보물상자·순풍·퀘스트·출석·도감·튜토리얼·소환 결과: UI 완료(가짜 provider), 경제 규칙 S2 진행 중 / 환생은 그다음

### M4 아트·광고 (일부 선행)
- [x] 도트 팩 v0.2 적용: 에셋 62개 + LICENSES.json(OWN), SpriteBank(배·적·보스·발사체·fx·코인), 선원 초상
- [x] 소리: AudioPort·렌더 연결, 음원 등록(효과음 자작, 배경음 CC0+자작 — b8a06f5). 실기기에서 귀로 확인
- [ ] AdMob 보상형 + UMP, Crashlytics·Analytics, 개인정보처리방침·app-ads.txt (platform 레인 — 세션 필요)

### M5 AOS 출시 · M6 iOS·랭킹
- 설계서 11장 DoD 그대로.

## 레인 상태

| 레인 | 세션 | 브랜치 | 상태 | 마지막 작업 | 막힌 것 |
| --- | --- | --- | --- | --- | --- |
| battle | S1 | main | M1 코어 완료, export-events 남음 | `battle/` 6개 파일, 테스트 9 + 시나리오 2 | - |
| economy | S2 | lane/economy | 스펙 승인, 강화 효과 함수·UpgradePart (cf0f333) | 뼈대 `EconomySystem` | - |
| render | S3 | lane/render | 스펙 초안 `render-battle-replay` | 빈 `BattleGame`, 합성 전투 기록 준비됨 | - |
| ui | S4 | lane/ui | 스펙 `ui-tabs` 승인 대기 | 탭 4개 자리, 샘플 상태 4개 준비됨 | - |
| platform | S5 | lane/platform | 세션 시작 대기 (`D:\Projects\pde-platform`) | - | - |
| art | S3 (2단계) | - | M3부터 | - | - |

## 그래픽 품질 기준 (사용자, 2026-10-14)
**최소 기준 = `D:\Projects\이미지참고용attle_ship.gif`**(640×360, 142프레임). 앞으로 계속 높인다. 렌더·UI·아트 작업은 이 화면과 나란히 비교해 못 미치면 끝난 것이 아니다.
기준의 특징: 층진 하늘 띠·도트 구름, 깊이별 바다 띠와 가로 물결 줄, 디테일 있는 범선과 포구 화염, 촘촘한 컬러 무리, 도트 비트맵 숫자(흰 글자·어두운 외곽선)와 큰 노란 '×4 COMBO' 배너, 배로 날아가는 코인 반짝임, 캔버스 안 도트 HUD(왼쪽 위 골드·가운데 '12-2'·오른쪽 위 붉은 막대), 아래 선원 바(등급 색 테두리 큰 초상).

## 사람이 해야 할 일 (S1이 모아 둔다)
| 무엇 | 왜 | 어디 |
| --- | --- | --- |
| **M2 관문 실기기 확인** (손맛 + 60fps) | 손맛은 sim으로 못 잰다. 통과 전엔 M3 이후를 '다듬기'로만 진행 | `docs/DEVICE_TEST.md` |
| 광고·분석 계정(AdMob·Firebase 프로젝트, google-services.json) | M4 광고·Crashlytics (platform 세션 S5는 열림) | `docs/store/firebase.md`, `docs/store/admob.md` |
| 업로드 키(릴리스 서명) | M5 Play 업로드 | `docs/store/android-release.md` |
| **Analytics 보존 기간 (2개월/14개월) — 보류** | 개인정보처리방침·데이터 보안 양식 | 사용자가 나중에 정함 |
| app-ads.txt를 https://rich-fire.blogspot.com/ 루트에 올릴 수 있는지 | AdMob 판매자 확인 | `docs/store/app-ads.md` (S5 조사) |

## 미결 사항 (설계서 12장) → ADR

| 항목 | 상태 |
| --- | --- |
| 게임 이름·패키지 ID | 이름 **해적도트 원정대** 확정(2026-10-14). 패키지 ID는 임시 `repo.dot.pirate` (ADR-0002), M5 전 확정. 개발자 박은우 · repo.dev88@gmail.com · 웹사이트 https://rich-fire.blogspot.com/ |
| 화면 방향·태블릿 | 미정 (세로 고정 가정) |
| 최소 지원 OS | 미정 (Android 7.0 / iOS 13 제안) |
| 환생 해금 스테이지 | **40 확정** (설계서 12장 체크리스트 [x], sim 첫 환생 스테이지 50·32.6시간) |
| 보스 재도전 광고 버프 | **채택** (설계서 12장 [x], 함포 지원 버프 전투 반영 4d480ff) |
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

### 2026-10-17 · S1 · 재개: 레인 재배정
- 세션 새로 열림: S2 economy=pirate-dot-rpg-26, S3 render=-5d, S4 ui=-24, S5 platform=-e8 (각자 D:\Projects\pde-<레인>). 인계 1절의 레인별 할 일 그대로 배정, 무거운 작업은 S1에 slot 요청 후 하나씩.
- main 07b7f035 check --full 실행. 폰 미연결(adb 장치 없음) → 설치·실측은 연결 뒤.
- 사용자 피드백 21건(폰 20분 플레이) → 우선순위 P0/P1/P2로 정해 4레인 배정(계획 user-feedback-2026-10-17.md). 스토어 샷 굽기는 화면 변경 뒤로 보류. 브레이크 기준 = balance crews ±10% 유지(S2 (b)). 대보스 id 확정(kraken_titan), 튜토리얼 1~3 보스 enemy_ship 고정.
- 머지: S4 fever-break UI·S3 idle.heat·S5 도감 v2 초안·S2 분노 정리. **481af1be check --full 빨강(UI 골든 66장 — S4 HUD 변경을 빠른 check만으로 커밋)** → S4 수정 중, HUD처럼 여러 화면 걸리는 변경은 커밋 전 --full 필수로 지시. rage 정리 1단계(1eea1777). S2 #21: 튜토리얼 2단계에 bones(희귀 5연사) 확정 지급(9초), 시작 선원 octo 하나·튜토리얼 건너뛰어도 지급(S1 결정). S5 선원별 피해 계약(BattleView.crewDamage·BossCleared.mvp) 승인.

### 2026-10-16 · S1 · 저녁: 사용자 퇴근 — 인계
- 인계 문서: docs/plans/active/handoff-2026-10-16.md(오늘 사용자 요청 전체·상태·결정·머지 대기·재개 순서). 재개 시 이 문서부터.
- main 0918cd61 check --full 초록. 폰 분리로 마지막 빌드 미설치(폰 = 4ec29146 보급까지).

### 2026-10-16 · S1 · 낮: 실기기 피드백 반영 대량 머지
- 머지: 적 전부 멈춤 렌더 수정·충돌 연출·체력 막대 알약(40/15%)·피버(처치 1000 발동·질주·지그재그·오라)·발사 임팩트·등급 꼬리 v2·범위 임팩트 v2·타격감 v3·위협(원거리·가까이 등장·돌격대·한 대 상한 8%)·보스 행동 v2(탄막·돌진·소환·장판)·선원 개성 v2(조준 8종·연사·MISS·특징 40%·보호막 turtle·낙뢰 pelly·피버 서포트 pumpum·등급 템포·신화 폭발)·골드 재조정(세제곱·가속·세이브 v7)·화물칸 금고(골드 상한)·자동 강화는 광고 10분·젬 '처음 깬 보스만'·난이도 재조정·빠른 항해 돌파·현상금 B0~B5·환생 알림/설명·도감 필터/합치기 표시·신화 빨강 테두리·시트 버벅임 수정·운영자 선원 시험/세이브 백업·계열 v3 출격 엔진.
- 사용자 결정 대기 없음(계열 v3·도감 v2 승인). 진행 중: 계열 v3(레이저·원형·집속·기존 계열 타이밍), 도감 v2(보스 42종·대보스·먹물/삼키기/분열·자폭/떼), 보스전 카메라 위로, 보스 HP 처치 10~20초, 야간 100명 리포트.
- 남은 문제: 메모리 부족으로 sim·check 동시 실행 시 강제 종료 — 무거운 작업은 한 번에 하나. 폰 실측 p95 미확인.

### 2026-10-15 · S1 · 저녁: 탑다운 기본·T4-2·균형, 사용자 퇴근
- 머지: 탑다운 기본(T4-1)·엔진 옆모습 삭제(T4-2), 배 13%(scale 0.74·캡슐 동비율), 적 접근(캡슐·잡몹 속도×2), 배 키우는 재미(돛 1→4·선체·대포 단계), 지루함 해소 연출·UI·피버, 골드 연출 제거, 선원 줄 가림 수정, 탑다운 균형(f000a95, balance 통과)·진행 보정.
- 미해결(사용자 핵심): 적이 일정 거리에서 '전부' 멈춰 보임 — 엔진은 정상(S1 측정 정지 0) → 히트스톱 연속 발동 의심, S3 수정 중.
- 사용자 지시: 적 산발 스폰 패턴 추가(S2·S5), 내일 아침 폰 연결 시 모두 확인 가능하게.
- 밤새 배정: S3 히트스톱·60fps·T4-3, S4 T4-4·스킨 r2, S2 스폰 패턴·T4-2b·이벤트/도전, S5 배 크기 키 통합·스크린샷·내일 확인 목록.
- 밤 추가 머지: '적 전부 정지' 진짜 원인(렌더가 지난 파 poses를 그림, S3 e28ade1) 수정·60fps 상한·배터리, T4-2b·T4-4, 돌발 이벤트 5종, 스킨 r2, 배 크기 키 통합(waves.top.shipScale), 내일 아침 확인 목록(docs/plans/active/platform-device-check-topdown.md).
- 대기: S5 spawn-patterns(S2 검토), S2 즉석 도전, S3 T4-3(옆모습 전용 그림을 탑다운으로 옮긴 뒤 삭제), S5 스토어 스크린샷.

### 2026-10-15 · S1 · 밤: 탑다운 전환 진행
- 머지: 탑다운 T0 계약(S2), T1 엔진(S5, 리뷰 브랜치·S2 검토, 옆모습 바이트 동일), T2 렌더(배 가운데·바다·적27·보스14·실제 연결·골든 4기기·150마리 부하), 도크+시트(전체 화면)·태블릿 UI 배율, 환생 v2 1~3단계(세이브 v6)와 화면 6종, 보스 실패 안내, 전투력·진행 게이지·일괄 강화, 운영자 전장 방식 토글.
- 사용자 결정: 탑다운 전환(배 가운데·크게), 환생 v2 보물 바다 A안 잠정.
- 다음: 탑다운 적 밀도(초반 30~40·상한 150, S2), 보스 출발 반경·피격 방향(S5), 대포 반동 층(S3), T4 전환.

### 2026-10-15 · S1 · 저녁: 사거리·외형·환생 개편 결정, 탑다운 시험판
- 머지: 선원별 사거리(보이는 화면 안만 공격)·shipX 86, 배 부품 외형 단계 그림(선체7·돛5·망루6·화물7·대포7), 폭탄 v2(느린 비행·배속 연동·등급 꼬리), 교체 UX 수정, 전장 55%, release 즉시 종료 수정(R8 keep), 광고 복귀 보상 버그, 탑다운 전투 시험판(PROTO 빌드, 앱 ID .proto).
- 사용자 결정: 세로+탑다운 시험판 먼저(설치함 — 판정 대기), 전체 화면 전투 + 도크·끌어올리는 시트, 보스는 거리 두고 원거리, 환생 v2(보물지도 상점·명예 외형·전용 스킨·보상 상자·미리보기·새 콘텐츠 해금).
- 대기: 사용자 탑다운 시험판 판정 → 전투 구조 결정(현상금 계약 C1은 그 뒤). 폰 분리 중 — 기기 작업 중단.

### 2026-10-15 · S1 · 사용자 피드백 반영 (오후)
- 머지: 수동 편성(세이브 v5, ADR-0010), 선원 상세·편성 UI, 태블릿 대응, 포탄·폭발(PB 무기 36종), PB 카드 일러스트·글꼴 Jua, 스킨 r1 선원 줄, 소환 연출 v2, 보상 코인 연출, 배 부품 외형 단계(shipLook), 재실행 멈춤·광고 뒤 버벅임(효과음 플레이어 누적) 수정.
- 사용자 결정: 스킨 r1(파스텔·통통한 버튼·PB 카드, Jua) 전면 적용 / 무료 개발(크레딧 도구 금지) / 화면 유동 크기(태블릿 800×1280 포함, AGENTS 완료 조건) / 몬스터 한 파 10~24마리(총량 유지) / 배 1.5배·선원 초상 확대 / 총 전투력 표시·진행 게이지·일괄 강화 x1~x50·MAX / 지루함 해소: 돌발 이벤트·피버+즉석 도전·바다 분위기.
- 버그(사용자 신고): 광고 뒤 복귀 보상, 재실행 즉시 2골드 → 광고 중 pause 안 함(S5) + 오프라인 최소 5분(S2). Native Heap 증가(분당 10MB) 조사 중(S5).
- 실수: dc01b22를 check 실패 확인 없이 커밋(255febe로 수정). 앞으로 check 결과를 grep으로 확인 후 커밋.

### 2026-10-15 · S1 · 디자인 회의 (사용자)
- 사용자 결정: ① 스킨이 올드·허접 → '세련되고 아기자기'(디자인 퀄리티 1차, 만족할 때까지 계속 주문) ② UI 스킨·전장 연출 동시 진행 ③ 참고 게임은 S1 선정(버섯커 키우기·Legend of Slime·쿠키런 킹덤 UI·메이플 키우기)
  ④ 캐릭터: 전투 HD 도트(64px급) + 선원 카드·상세·소환은 고해상도 SD 일러스트 40장(AI 생성, OWN) ⑤ 접속 콘텐츠 4종 전부(선원 수집 강화·현상금 사냥·무료 항해 일지·업적/칭호+주말 이벤트)
  ⑥ 출전 = 기본 수동 편성 + '자동 편성' 버튼(설계서 4.3·4.8 변경) ⑦ 전장 그림 33% 확대(도트 배율 +1, 상자 45%) ⑧ 선원 카드 누르면 상세 화면.
- 배정: S4 새 스킨 시안(ui-skin-r1)·선원 상세·편성 UI, S3 일러스트 3명 시안·HD 도트 시안·전장 파티클, S2 수동 편성 코어(세이브 v5, LANES 위임), S5 재실행 멈춤 버그(main.dart 위임)·콘텐츠 4종 기획서.
- 사고(S5 보고): device_shots 수정 중 앱이 뒤에 있을 때 탭이 홈 화면 전화 앱에 들어감(통화 없음 확인) → 앞 앱 확인 안전장치, 사용자 확인 전 폰 입력 금지.

### 2026-10-15 · S1 · 실기기 첫 설치 (S24), 화면 배치 v2
- 한 일: 운영자 profile APK(32b7fb3)를 사용자 S24(SM-S921N, Android 16)에 adb 설치. 사용자 피드백 "버튼이 가리고 게임 화면이 안 보인다" →
  adb 화면 캡처로 전 탭 점검, 지시서 `docs/specs/layout-v2-brief.md`(전장 폭 채우기·높이 약 40%, 누르는 버튼은 전장 밖 상단 바·선원 줄, 탭 글자 14sp·선원 4열).
  머지: render 빙하·화산 적·보스·배 t2~t4, ui 창·시트·튜토리얼 도트화·설정 도트·소환 연출, platform 스토어 스크린샷 도구, economy c3.
- 추가: economy 8954692(expToNext.legend 20→30 → 첫 신화 30일, 모든 60일 목표 OK), LANES economy에 docs/balance/(야간 리포트). 야간 리포트는 로컬 실행(ADR-0006, CI 없음).
- 배정: S3·S4 배치 v2 최우선, S2 신화 비용 sim(순차)·30일 리포트·미결 2건, S5 디자인 퀄리티 벤치마크·단계안(사용자 논의 자료).

### 2026-10-15 · S1 · PC 재시작 후 재개, 레인 4개 재배정
- 세션 4개 모두 main 폴더에서 열림 → 각자 worktree 절대경로(D:\Projects\pde-<레인>)에서만 작업하도록 지시. c7=economy, 96=render, b7=ui, a1=platform.
- 머지: lane/economy e25de1d(초반 흐름), lane/render(렌더 품질 v1, 골든 7장 승인), lane/ui(도트 UI v1, 골든 12장 체크포인트 승인). pubspec `assets/ui/` 등록(5548687).
- main.dart 어댑터 연결(3e1efd6, S5 권장안): startAnalytics(Firebase/Noop)·AudioAdapter·AdMobAds(첫 프레임 뒤 start, 동의 시 Analytics 수집)·OfflineFullNotifier(pause/resume). dailyMax·enabled는 TODO(platform).
- 판단: UI v1은 기준 gif에 못 미침(Material HUD, 긴 선원 카드, 잘리는 이름) → v2 지시. 캔버스 HUD·선원 바는 render 소유로 확정, 완성 뒤 UI가 위쪽 HUD 걷어냄.
- 추가: platform abf2f9f(아이콘 스크립트·testRing·런처 이름), render v2(선원 바·범위 합산 숫자, 골든 5장), ui v2(정사각 초상 카드·실루엣·assets/ui 아이콘, 골든 11장),
  economy fd535ed(notificationsDailyMax) 머지. 계약 I `FleetSlot.rarity`(렌더 요청). main.dart dailyMax = 테이블 값.
- 실수(레인): ui 커밋에 골든 실패 산출물 `test/ui/failures/*.png`가 들어옴 → 제거, `.gitignore`에 `**/test/**/failures/`·`.kotlin/`.
- 사용자 결정(환생 3): 반복 보스 카드 = 짝수 스테이지만 1장(c3, economy 구현), 빠른 항해 = 환생 뒤 bestStage×0.3(올림) 이하 스테이지는 파 없이 보스(f0).
  조사(다른 키우기 게임: TT2 시작 지점 최대 90%, 진행 보상은 최고 기록 갱신 때만)를 보고 결정.
- 추가: 세이브 v4 `Settings.notifications`(ADR-0009), 빠른 항해 `waves.rebirthSkip`(battle), 앱 아이콘·스플래시, UI 16px 아이콘, 산호초 보스 스프라이트 요청, DEVICE_TEST 3절.
- 추가2: ui d141e30(Material HUD 제거·전장 오버레이·알림 토글·배 탭 아이콘), render UI 아이콘 14종·산호초 보스, platform 음원 후보표·자작 칩튠 생성기, S2 c3(c6647bc, 미머지).
- 사용자 위임(음원): 효과음 전부 자작(OWN), 배경음 coral·storm·phantom = CC0(Junkala ×2·Void Estate), glacier·volcano·abyss = 자작. ffmpeg(winget) 설치·ogg 변환·등록 진행 중(S1).
- 발견: PC 메모리 부족으로 S2 sim 6개가 강제 종료 → 동시 2개 이하로 재실행. 배 등급 스프라이트 t1뿐(stage 30부터 상자) → S3가 t2~t4 먼저.
- 음원 등록 b8a06f5: 효과음 16(자작 OWN)·배경음 6(CC0-1.0 3 + 자작 3), assets/audio 2.86MB, ffmpeg 9.0.2(winget). render e78b3c1(폭풍해)·ui 700576a(도트 아이콘 교체) 머지.
- 다음 할 일: S2 첫 신화 28일+ 값, S3 배 t2~t4, S4 도트 아이콘 교체, S5 스토어 스크린샷 자동 생성.

### 2026-10-14 · S1 · M3 계약·보스, 레인 통합 (오후)
- 한 일: 해역 보스·무한 항해(edc81e3), 세이브 v3(16dda02, ADR-0008), lastSummon·AckSummonResult, GrantAdReward.choice·lastOfflineGold, ClaimDaily(questId), 튜토리얼 3단계 보스.
  레인 머지: render(M3 연출·해역 배경·보스·보물상자·live 통합 테스트), ui(코어 루프·순풍·목표·도감·상자·튜토리얼·퀘스트·출석·소환 결과), economy(offlinePreview·무료 10연·증표·성장·옥토 카드).
  M2 관문 안내 `docs/DEVICE_TEST.md`, profile APK 빌드 확인. LANES: render가 art 경로(assets/, tools/art/) 함께 소유(같은 S3 세션).
- 사용자 결정: 증표 조건 확대, 성장 수치 목표에 맞춤, 옥토 카드 나눠 지급(보스 4번마다), 스테이지 40 = 경과 시간 기준(재결정), 상자 광고 골드/젬 선택, 퀘스트마다 젬 10, 출석 20·20·30·30·40·50 + 영웅.
- 발견: 보호막 피해 0이면 깨는 계열 없는 편성이 150에서 영원히 막힘(sim) → 25% 부분 피해. 보스 HP 1e21대에서 테스트 피해 100은 double 정밀도 밖.
- 추가: 전설 고유 능력 40명(19aa020), 도트 팩 v0.2 + pubspec assets(c3e96fa), AudioPort(5b8ef89), boss HP 16→12(49de15b — 계속 접속 sim 7.2 지표 전부 OK).
- 추가: 처치 퀘스트·순풍(골드·배속)·함포 지원 버프 전투 반영(4d480ff), 경제 M3 메타 B1~B10 머지, 스테이지 40 판정을 '첫날 안'으로 정리(설계서 7.2).
- 다음 할 일: 사람 확인 목록(위 표), economy 환생, ui 실제 함수 교체, render 큰 순간 연출

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
