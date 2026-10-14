# 계획: M3 메타 화면

- 레인: ui (S4) · 브랜치 `lane/ui` · 시작 2026-10-14
- 스펙: `docs/specs/ui-m3-meta.md` (승인됨 2026-10-14, S1) · 요청서: `docs/contracts/requests/ui-m3-meta.md`

## 단계 (계약·경제가 오는 순서에 맞춘다)
- [x] 1. ③ 순풍 표시 — `buffs.tailwindUntil`과 `clockProvider`만으로 (기준 4)
- [x] 2. ① 목표 막대 — `nextGoalProvider`(기본 null = 숨김, S2 B1 오면 교체) (기준 1)
- [x] 3. ⑤ 도감 보너스 줄 — `collectionBonusProvider`(기본 null, S2 B9 오면 교체) (기준 7)
- [ ] 4. ② 보물상자 — S1 `BattleView.chest` + S2 B2·B3 뒤 (기준 2·3)
- [ ] 5. ④ 퀘스트·출석 시트 — S1 A2·A3 + S2 B7·B8 뒤 (기준 5·6)
- [ ] 6. ⑥ 튜토리얼 — S1 A4·A5 + S2 B10 뒤 (기준 8·9)
- [ ] 7. 영어 골든 3장 + 바뀐 골든 재생성 → S1 승인 (기준 10)
- [ ] 8. `check --full` → 진척 문서 → 커밋 → S1 보고 (단계마다)

## 메모
- 가짜 provider 방식: 기본값은 “없음”(화면에 안 나옴) → 앱 동작은 그대로, 테스트는 provider를 덮어 화면을 시험한다. 경제 함수가 오면 provider 본문만 바꾼다.
- 순풍·상자·퀘스트 아이콘은 설계서 4.12대로 전장 위에 둔다(HUD가 아니라). 골든은 단계 7에서 한 번에 재생성.
