# economy: M1 EconomySystem + game_cli sim

- 레인: economy (S2) · 브랜치 `lane/economy` · 시작 2026-10-14
- 스펙: `docs/specs/economy-m1.md` (승인 2026-10-14, 사용자)
- 설계서: 4.2 · 4.3.1 · 4.3.3 · 4.7 · 4.8(상한) · 7.2 · 9.3

## 단계
- [x] 0. 스펙 승인 (사람) · 결정 ①②③
- [x] 1. `ship_stats.dart` 순수 함수 + 테스트 → `docs/contracts/requests/economy-stats.md`로 S1에 시그니처 공유
- [x] 2. 테이블 정리(rarities·growth) + 모델(`crew_tables.dart`) + `gen_tables`
- [ ] 3. UpgradePart (기준 1~4)
- [ ] 4. Summon + 천장 + receiveCard (기준 5~8, 11)
- [ ] 5. MergeAllCards · PromoteCrew (기준 9~10)
- [ ] 6. ClaimOffline + 보스 카드 (기준 12)
- [ ] 7. 운영자 명령 4종
- [ ] 8. `game_cli sim` + 7.2 리포트, check 스모크 활성화 (기준 13)

## 검증
- 단계마다 테스트 먼저(실패 확인) → 구현 → `tool\check.bat`. 커밋 전 `--full`.
- 테이블 변경 시 sim 리포트를 진척 문서에 첨부.

## 메모
- 경제가 쓰는 숫자는 전부 테이블에서(0·1 외 리터럴 금지).
- `crews.json`의 `family` 값은 건드리지 않는다(main에서 support→shock, `skill` 필드 추가 머지 예정).
