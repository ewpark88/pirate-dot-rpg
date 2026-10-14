# 계획: 코어 루프 화면 (보스 도전 · 복귀 오프라인 보상 · 설정 · 운영자 렌더 묶음)

- 레인: ui (S4) · 브랜치 `lane/ui` · 시작 2026-10-14
- 스펙: `docs/specs/ui-core-loop.md` (승인됨 2026-10-14, S1)

## 단계
- [ ] 1. 보스 도전 버튼·파밍 표시 (기준 1~2)
- [ ] 2. 설정 화면 + 앱 언어 + 전장 JuiceSettings 연결 (기준 7~9)
- [ ] 3. `battleGameProvider` + 운영자 렌더 묶음 (기준 10~11)
- [ ] 4. `clockProvider`·`offlinePreviewProvider`(가짜 → S2 함수로 교체) + 복귀 팝업 (기준 3~6)
- [ ] 5. 영어 골든 2장(팝업·설정) → S1 승인 후 커밋 (기준 12)
- [ ] 6. `check --full` → 진척 문서 → 커밋 → S1 보고

## 검증 방법
- `apps/game/test/ui/*_test.dart` 위젯 테스트, `tool\check.bat --full`

## 메모
- S2 `offlinePreview(GameState, GameTables, DateTime now)` 대기 (S1이 요청). 오기 전에는 UI의 미리보기 provider를 테스트에서 가짜로 덮는다.
- 복귀: main의 AppLifecycleListener가 `EngineHost.resume()`을 부른 뒤 엔진 state.savedAt = 멈춘 시각. UI는 resumed 뒤 첫 프레임에 미리보기를 구한다.
