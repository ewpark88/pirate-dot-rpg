# 계획: 운영자 패널 1차

- 레인: ui (S4) · 브랜치 `lane/ui` · 시작 2026-10-14
- 스펙: `docs/specs/ui-operator-panel.md` (승인됨 2026-10-14, S1) · 설계서 6.10

## 단계
- [x] 1. 샘플 상태 읽기(`loadSampleState`, SaveCodec.migrate 경유) — 테스트 먼저 (기준 1)
- [x] 2. op ARB(ko/en)
- [x] 3. 패널 위젯: 저장·전장·선원·경제 묶음 (기준 1~7)
- [x] 4. 열기 제스처(HUD 스테이지 5번, kOperator 빌드에서만 등록)·하단 시트(HUD 가리지 않음) (기준 8), 상태 갱신 즉시 반영 (기준 1-1)
- [x] 5. 영어 골든 1장 (기준 9) — S1 승인
- [x] 6. `check --full` → 진척 문서 → 커밋 → S1 보고

## 검증 방법
- `apps/game/test/ui/operator_panel_test.dart`, 골든 `apps/game/test/goldens/en_operator_panel.png`, `tool\check.bat --full`

## 메모
- `kOperator`는 상수라 테스트에서 켤 수 없다 → 패널 위젯을 직접 띄워 시험하고, 기본 빌드에서 제스처가 없는 것만 앱으로 확인한다.
