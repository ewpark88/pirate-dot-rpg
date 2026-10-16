# 요청: 현상금 사냥 B3 연출 (platform S5 → S3)

- 2026-10-16 · 계획 `docs/plans/active/platform-bounty-topdown.md`(S1 승인) · 기획 7절
- **우선순위(S1)**: 체력 막대 → 상태 아이콘 → T4-3 2단계 **다 끝난 뒤** 시작.
- 기다리는 계약: B0(S2) `BattleView.bounty`{bossId, tier, ticksLeft}, 이벤트 `BountyStarted`·`BountyCleared(reward)`·`BountyFailed(reason)`.

| # | 할 것 |
| --- | --- |
| 1 | 시작 컷인 **수배 포스터**(양피지 + 보스 초상 + 현상금 숫자, 0.8초) — 기존 해역 보스 컷인(fx_map cutIn) 틀 재사용 |
| 2 | 현상금 보스: 기존 td_boss 그림 + 수배 표식(머리 위 작은 포스터 핀 등). 전투 규칙은 본 보스와 같다(위쪽 출발 → standoff 100 원) |
| 3 | 타이머: 보스 타이머 자리(`bounty.ticksLeft`) |
| 4 | 끝 연출: 처치 = 보상 숫자 올라가기, 실패 = 짧은 '도망쳤다' (문구는 S4) |
- 완료: 4기기 골든(포스터·전투·결과), 60fps 상한 유지.
