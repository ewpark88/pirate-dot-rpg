# 진척: ui 레인 (S4)

## 현재 위치
| 항목 | 내용 |
| --- | --- |
| 계획 | `docs/plans/active/ui-tabs.md` — 하단 탭 1차(배·소환·선원) + 상단 HUD |
| 상태 | 단계 1~6 커밋 (골든 S1 승인) |
| 기다리는 것 | S1의 `sample_states.g.dart` 생성물(운영자 샘플 상태) |

## 세션 로그 (최신이 위)

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
