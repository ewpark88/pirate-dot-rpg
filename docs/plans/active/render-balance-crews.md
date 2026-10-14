# 계획: 선원 균형 검사 `game_cli balance crews`

- 스펙: `docs/specs/render-balance-crews.md` (**승인 대기**, Q1 배 보호분 측정·Q2 κ·Q3 check 연결) · 레인: render(S3)

## 단계
- [ ] 0. 스펙 승인 · Q1~Q3 결정
- [ ] 1. 테스트 먼저(`packages/game_cli/test/balance/`): 수용 기준 1~7
- [ ] 2. `lib/src/balance/arena.dart` — 엔진 한 판(선원·레벨·장면·시간) → 피해·배 접촉 집계
- [ ] 3. `crew_scores.dart` — 200칸·중앙값·±10% 판정, 지원 환산
- [ ] 4. `combos.dart` — 같은 계열 2명 이하 6명 조합 N개·상위 1% 판정
- [ ] 5. `balance.dart` crews 서브커맨드(마크다운·JSON·종료 코드·옵션)
- [ ] 6. 실제 테이블로 실행 → 결과 표를 S1에 전달(수치 조정은 S1) → `tool\check.bat --full` → 커밋

## 검증 방법
`dart test packages/game_cli/test/balance`, `dart run game_cli balance crews --quick`, `tool\check.bat --full`.
