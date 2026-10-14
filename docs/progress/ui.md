# 진척: ui 레인 (S4)

## 현재 위치
| 항목 | 내용 |
| --- | --- |
| 계획 | 완료: `done/ui-core-loop.md` → 다음: 스펙 `ui-m3-meta` |
| 상태 | 코어 루프 커밋 (골든 7장 S1 승인) |
| 기다리는 것 | - |

## 세션 로그 (최신이 위)

### 2026-10-14 · S4 · 코어 루프 화면
- 한 일: 스펙 승인(3e6bb84) → 3b8e377 보스 도전·파밍 표시. 설정 화면(HUD 톱니, 9항목 → SetSetting, 앱 언어 = settings.lang),
  `battleGameProvider`가 BattleGame을 만들고 설정 4개를 JuiceSettings로 넘김, 운영자 ‘렌더’ 묶음(라이브·데모·부하, 성능 표시, 히트박스),
  복귀 오프라인 팝업(`OfflineRewardGate`: 시작 첫 프레임 + resume 다음 프레임, 중복 금지, 받기만). `check --full` 통과(위젯 60개).
- 다음 할 일: M3 메타 화면 스펙(`ui-m3-meta`)
- 마무리: main e883272 머지 → `offlinePreviewProvider`를 경제 `offlinePreview`로 연결(TODO 제거), 소환 비용 `summonCostFor`(첫 10연이면 ‘무료’)
- 남은 문제:
  - 골든 글꼴(SDK Roboto)에 한글이 없어 설정의 ‘한국어’ 버튼이 네모로 그려진다 — Galmuri 도입 때 해소
  - resume 직후 프레임이 없을 수 있어 `ensureVisualUpdate`로 직접 요청한다

### 2026-10-14 · S4 · 운영자 패널 커밋, 코어 루프 스펙
- 한 일: dbb986f 운영자 패널(골든 S1 승인), main 298b02c(저장·복원) 머지 315e0ab — `flutter pub get` 후 `check --full` 통과.
  `docs/specs/ui-core-loop.md` 초안(보스 도전·복귀 오프라인 팝업·설정 화면·운영자 렌더 묶음). main 1c31c32 다시 머지 — main이 옛 커밋(dbb986f)을 머지한 뒤 레인 검사가 main 파일을 ui 변경으로 잡던 문제 해소.
- 다음 할 일: 승인 → 계획 → 테스트 먼저 → 구현
- 남은 문제: 오프라인 미리보기 함수가 없어 S2에 `offlinePreview` 요청(S1 중계). 일시정지 저장 때 savedAt 갱신 여부 확인 요청

### 2026-10-14 · S4 · 운영자 패널 1차
- 한 일: b5aa3e6 (전장 주입점·골든 재생성·스펙, S1이 main 머지). 운영자 패널: 샘플 4개 → `OpLoadState`(SaveCodec.migrate 경유),
  배속 1/2/4, 무적·쿨타임 0, 보스 소환, 스테이지 이동, 골드·젬 지급. 열기는 HUD 스테이지 글자 5번(`if (kOperator)`일 때만 제스처 등록),
  하단 시트 최대 70% 높이(HUD 안 가림), 바깥 어둡게 안 함. 세이브 v2 머지 후 `check --full` 통과(위젯 테스트 41개).
- 다음 할 일: 골든 승인 → 커밋 → 다음 계획(항해 탭·설정 화면 — 설정이 생기면 운영자 열기를 버전 글자로 옮김)
- 남은 문제: `kOperator`가 상수라 앱 안에서 제스처→패널 경로는 테스트 못 함(게이트 위젯 단독 테스트로 대신)

### 2026-10-14 · S4 · 전장 분리와 운영자 패널 스펙
- 한 일: 렌더 레인의 새 전장 그림이 들어오며 UI 골든 4장이 깨짐(전장 영역만 22% 차이). S1 결정 B — UI 골든은 HUD와 탭 패널만 본다.
  home_screen에 `battleViewBuilderProvider` 주입점, UI 테스트는 빈 상자로 바꿈. `BattleGame(feed, tables)` 전달. 골든 재생성(미커밋, S1 승인 대기).
  운영자 패널 1차 스펙 초안 작성. main 머지(`sample_states.g.dart` 포함) 후 `check --full` 통과.
- 다음 할 일: 승인 → 골든·home_screen·스펙 커밋 → 운영자 패널 테스트 먼저 → 구현

### 2026-10-14 · S4 · 탭 화면 1차 구현
- 한 일:
  - 스펙 `docs/specs/ui-tabs.md` 승인(S1, 사용자 위임 확인) → 단계별 커밋:
    7b3e83b 상태 구독(`gameStateProvider`·`CommandSink`) · 630d1b7 상단 HUD + ui ARB + 테이블 nameKey 문구(`tableText`) ·
    3f6fa8c 배 탭 (S1이 main에 1차 머지) · e1d1bf0/f122f8f 소환 탭 · d4e7fd4 선원 탭
  - 경제 함수 사용: `partEffect`·`partCost`·`rarityOfLevel`·`summonCost`·`canSummon`·`promoteStatus`. UI에 계산식 없음
  - 엔진 연결(main c20e043) 뒤 20Hz 갱신 대비: 모든 위젯이 `gameStateProvider.select`로 필요한 값만 구독
  - 영어 골든 4장 `apps/game/test/goldens/en_*.png` — SDK Roboto/MaterialIcons를 읽어 실제 글자로 그린다(Ahem 네모 대신)
- 검증: `tool\check.bat --full` 통과(위젯 테스트 30개)
- 다음 할 일: 골든 커밋 → 항해 탭(해역 지도·환생), 배 탭 꾹 누르기·자동 강화·배 등급 막대, 선원 상세 창, 무료 광고 소환·증표 상점, 설정, 운영자 패널
- 남은 문제:
  - 영어 선원 이름이 5열 격자에서 말줄임된다(“Octo the B…”). 선원 상세 창에서 전체 이름을 보이거나 4열로 바꿀지 다음 계획에서 정한다
  - 골든은 Windows에서 생성. 다른 OS에서는 글자 렌더 차이로 골든이 깨질 수 있다
  - 운영자 “샘플 상태 불러오기”는 fixtures를 앱 에셋으로 등록해야 해서 보류
  - 주의: 생성된 l10n 함수의 인자 순서가 ARB 문구 속 순서와 다를 수 있다(`uiSummonPity(count, rarity)`). 호출 전에 생성된 시그니처를 확인

### 2026-10-14 · S4 · 레인 시작
- 한 일: worktree `D:\Projects\pde-ui`(lane/ui) 진입, 레인 브리핑·계약·테이블 확인, 스펙+계획 초안 작성.
- 소환 확률은 설계서(65/27/7/1)가 기준 — S2가 `rarities.json`을 맞췄다(골든에 반영).
- main e4edf73 머지(레인이 `docs/specs/<레인>-` 소유) → 스펙을 `docs/specs/ui-tabs.md`로 분리.
