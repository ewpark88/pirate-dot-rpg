# 계획: 선원 균형 검사 `game_cli balance crews`

- 스펙: `docs/specs/render-balance-crews.md` (승인됨 2026-10-14, S1 — Q1 (b) 선체 레벨, Q2 κ 0.5, Q3 --quick 시간 보고) · 레인: render(S3)

## 단계
- [x] 0. 스펙 승인 · Q1~Q3 결정
- [x] 1. 테스트 먼저(`packages/game_cli/test/balance/`): 수용 기준 1~7
- [x] 2. `lib/src/balance/arena.dart` — 엔진 한 판(선원·레벨·장면·시간) → 피해·배 접촉 집계
- [x] 3. `crew_scores.dart` — 200칸·중앙값·±10% 판정, 지원 환산
- [x] 4. `combos.dart` — 같은 계열 2명 이하 6명 조합 N개·상위 1% 판정
- [x] 5. `balance.dart` crews 서브커맨드(마크다운·JSON·종료 코드·옵션)
- [x] 6. 실제 테이블로 실행(`render-balance-crews-report.md`) → S1에 전달(수치 조정은 S1) → 커밋

## 메모
- 측정 시간: `--quick` 약 4.3초(dart 시작 포함), 전체(200칸 + 지원 환산 + 조합 500) 28.6초.
- 결과: 실패(종료 코드 1) — 계열별 편차가 큼(아래 진척 문서). 조합 상위 1% ×1.267로 통과.

## 검증 방법
`dart test packages/game_cli/test/balance`, `dart run game_cli balance crews --quick`, `tool\check.bat --full`.
