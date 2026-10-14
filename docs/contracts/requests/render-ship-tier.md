# 계약 변경 요청: render-ship-tier (render → S1)

- 요청: S3 render · 2026-10-14 · 관련 스펙: `docs/specs/render-moments.md`
- 상태: 제안 (S1 결정 대기)

## G. `BattleView.shipTierId` (String, JSON 생략 시 `ship_tiers.json` 첫 등급 id)
- 지금 배 등급 id(`dinghy`·`sloop`·`warship`·`ghost`). 렌더가 `ship_tiers.json tiers[].sprite`로 배 그림을 고른다.
- 이유: `ShipTierUp`은 바뀌는 순간에만 나온다. 앱을 켠 직후·기록 재생(데모·부하·골든)에서는 지금 등급을 알 수 없다.
- 호환: 선택 필드 → 기존 기록 호환. `BattleView`는 세이브에 없음.
