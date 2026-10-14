# 계획: 렌더 — '큰 순간' 연출

- 스펙: `docs/specs/render-moments.md` (**승인 대기**) · 계약 요청: `docs/contracts/requests/render-ship-tier.md` · 레인: render(S3)

## 단계
- [ ] 0. 스펙 승인 · 계약 G 결정
- [ ] 1. fx_map `cutIn`·`pillar`·`shipLook`·`regionSweep`
- [ ] 2. 테스트 먼저: 수용 기준 1~5
- [ ] 3. 해역 보스 판정·컷인(`BattleGame.cutIn`, `resetSeenBosses`)
- [ ] 4. 승급 빛기둥·배 모양(등급 스프라이트 키 `ship:<tierId>`), 해역 이동 sweep
- [ ] 5. 골든 `battle_cutin.png` → 승인 → `tool\check.bat --full` → 커밋

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`.
