# 계획: M3 메타 화면

- 레인: ui (S4) · 브랜치 `lane/ui` · 시작 2026-10-14
- 스펙: `docs/specs/ui-m3-meta.md` (승인됨 2026-10-14, S1) · 요청서: `docs/contracts/requests/ui-m3-meta.md`

## 단계 (계약·경제가 오는 순서에 맞춘다)
- [x] 1. ③ 순풍 표시 — `buffs.tailwindUntil`과 `clockProvider`만으로 (기준 4)
- [x] 2. ① 목표 막대 — `nextGoalProvider`(기본 null = 숨김, S2 B1 오면 교체) (기준 1)
- [x] 3. ⑤ 도감 보너스 줄 — `collectionBonusProvider`(기본 null, S2 B9 오면 교체) (기준 7)
- [x] 4. ② 보물상자 — `battle.chest` 탭 영역·링, 금액은 `chestRewardProvider`(S2 B3 전까지 숨김) (기준 2·3)
- [x] 5. ④ 퀘스트·출석 시트 — 전장 아이콘(빨간 점)→하단 시트, `dailyQuestsProvider`·`attendanceProvider`(S2 B7·B8 전까지 숨김) (기준 5·6)
- [x] 6. ⑥ 튜토리얼 — 말풍선(전장·탭 사이 줄)·손가락(TutorialSpot)·건너뛰기·확인(1·6단계 TutorialAck), 4단계는 10회 소환 직후 Ack(임시) (기준 8·9)
- [x] 6-1. ⑦ 소환 결과 연출 — `lastSummon`(main 8e7567d) → 카드 뒤집기 창, 확인 → AckSummonResult(+튜토리얼 4단계 Ack) (기준 11)
- [x] 7. 영어 골든 4장(en_m3_hud·en_daily_sheet·en_tutorial_step2·en_summon_result) — S1 승인 (기준 10·11)
- [ ] 8. `check --full` → 진척 문서 → 커밋 → S1 보고 (단계마다)

## 메모
- 가짜 provider 방식: 기본값은 “없음”(화면에 안 나옴) → 앱 동작은 그대로, 테스트는 provider를 덮어 화면을 시험한다. 경제 함수가 오면 provider 본문만 바꾼다.
- 순풍·상자·퀘스트 아이콘은 설계서 4.12대로 전장 위에 둔다(HUD가 아니라). 골든은 단계 7에서 한 번에 재생성.
