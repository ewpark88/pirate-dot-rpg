# 계획: 렌더 — 해역 배경 6종 · 보스 연출

- 스펙: `docs/specs/render-regions.md` (**승인 대기**) · 계약 요청: `docs/contracts/requests/render-stage.md` · 레인: render(S3)

## 단계
- [ ] 0. 스펙 승인 · 계약 D 결정
- [ ] 1. `fx_map.json` backgrounds·backgroundFadeMs·bossEntrance·bossFailed, `juice.json` bossKill.coinRain + 모델·검증
- [ ] 2. 테스트 먼저: 수용 기준 1~6 → 실패 확인
- [ ] 3. 해역 결정·배경 그리기·전환 섞기 (`paint/background_painter.dart`)
- [ ] 4. 보스 등장 경고·처치 코인 비·실패 어두움
- [ ] 5. 골든 `battle_boss_storm.png` → 승인 → `tool\check.bat --full` → 커밋

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`.
