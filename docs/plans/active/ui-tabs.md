# 계획: 하단 탭 화면 1차 (배 강화 · 소환 · 원정대 · 상단 HUD)

- 레인: ui (S4) · 브랜치 `lane/ui` · 시작 2026-10-14
- 설계서: 4.2 · 4.3 · 4.5 · 4.9 · 4.12
- 스펙: `docs/specs/ui-tabs.md`

## 단계
- [x] 0. 스펙 승인 (2026-10-14, S1 — 사용자 위임 확인)
- [x] 1. `gameStateProvider` + `CommandSink` + 픽스처 로더(테스트용) — 테스트 먼저
- [x] 2. 상단 HUD (기준 1~3)
- [ ] 3. 배 탭 (기준 4~5)
- [ ] 4. 소환 탭 (기준 6)
- [ ] 5. 선원 탭 (기준 7~8)
- [ ] 6. 영어 골든 4장 (기준 9), 운영자 샘플 상태 버튼
- [ ] 7. `tool\check.bat --full` → 진척 문서 → 커밋(lane/ui, push 안 함)

## 검증 방법
- `apps/game/test/ui/*_test.dart` 위젯 테스트, `apps/game/test/goldens/` 영어 골든, `tool\check.bat --full`

## 메모 · 기다리는 것
- 경제 레인(S2): 강화 효과·비용, 승급 비용·조건, 소환 젬 비용 함수 → 받으면 TODO(economy) 자리 교체
- main: 8번째 계열 `support→shock`, ARB 키 `battleFamilyShock` 머지 예정 → 머지 후 `git merge main`
- 소환 확률: 설계서(65/27/7/1)가 기준, `rarities.json` 수정은 S2 몫(S1 확인). UI는 테이블 값을 그대로 표시
