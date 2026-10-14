# 계획: 환생 화면 · 보스 약점

- 레인: ui (S4) · 브랜치 `lane/ui` · 시작 2026-10-14
- 스펙: `docs/specs/ui-rebirth-boss.md` (승인됨 2026-10-14, S1)

## 단계
- [x] 1. ② 보스 약점 칩 — 보스 이름(BossDef.nameKey) + 약점 계열(skills families nameKey), 테이블만으로 (기준 4)
- [x] 2. ① 항해 탭 환생 카드 — `rebirthPreviewProvider`(기본 null, S2 함수 오면 교체) (기준 1·2)
- [x] 3. 환생 확인 창 → Rebirth (기준 3)
- [x] 4. 영어 골든 2장(en_rebirth_card·en_rebirth_dialog) + 항해 탭이 보이는 3장 갱신 — S1 승인(환생 숫자 규칙은 미정, S2 함수 교체 때 재승인) (기준 5)
- [ ] 5. `check --full` → 진척 문서 → 커밋 → S1 보고

## 메모
- main 553e883: 경제 화면 타입은 이제 `game_core.dart`에서 바로 (economy_views는 호환용).
