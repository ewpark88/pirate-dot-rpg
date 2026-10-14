# 계획: 렌더 — '큰 순간' 연출

- 스펙: `docs/specs/render-moments.md` (승인됨 2026-10-14, S1 — 계약 G 거절: stage 파생) · 계약 요청: `docs/contracts/requests/render-ship-tier.md` · 레인: render(S3)

## 단계
- [x] 0. 스펙 승인 · 계약 G 거절(stage 파생)
- [x] 0b. `Backdrop`을 `regions.regionAt(stage)`로(무한 항해 반복)
- [x] 1. fx_map `cutIn`·`pillar`·`shipLook`·`regionSweep`
- [x] 2. 테스트 먼저: 수용 기준 1~5
- [x] 3. 해역 보스 판정·컷인(`BattleGame.cutIn`, `resetSeenBosses`)
- [x] 4. 승급 빛기둥·배 모양(등급 스프라이트 키 `ship:<tierId>`), 해역 이동 sweep
- [ ] 5. 골든 `battle_cutin.png`(새)·`battle_boss_storm.png`(stage 75 → sloop 배로 갱신) S1 확인 대기

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`.
