# 계획: 렌더 — 해역 배경 6종 · 보스 연출

- 스펙: `docs/specs/render-regions.md` (승인됨 2026-10-14, S1 — 계약 D 수용) · 계약 요청: `docs/contracts/requests/render-stage.md` · 레인: render(S3)

## 단계
- [x] 0. 스펙 승인 · 계약 D 수용 (main 반영 대기)
- [x] 1. `fx_map.json` backgrounds·backgroundFadeMs·bossEntrance·bossFailed·bossLook·shield·tierColors, `juice.json` bossKill.coinRain + 모델·검증
- [x] 2. 테스트 먼저: 수용 기준 1~7 (`regions_test.dart`) — 8·9(shielded·tier)는 계약 main 반영 후
- [x] 3. 해역 결정·배경 그리기·전환 섞기 (`scene/backdrop.dart`, `paint/stage_painter.dart`)
- [x] 4. 보스 등장 경고·처치 코인 비·실패 어두움
- [x] 4b. 보스 모양 13종+촉수, 보호막 테두리·깨짐, tier 테두리
- [x] 4c. scene이 frame.stage로 Backdrop 갱신 + 보물상자(BattleView.chest) — b78d0fe
- [x] 5. 골든 2장 재승인 d640aad · 보스 골든 battle_boss_storm.png (S1 승인, storm_pirate·deep_sub 색 밝게)

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`.
