# 계약 변경 요청: render-ship-tier (render → S1)

- 요청: S3 render · 2026-10-14 · 관련 스펙: `docs/specs/render-moments.md`
- 상태: **거절 — stage에서 파생** (2026-10-14, S1)

## G. `BattleView.shipTierId` (String, JSON 생략 시 `ship_tiers.json` 첫 등급 id)
- 지금 배 등급 id(`dinghy`·`sloop`·`warship`·`ghost`). 렌더가 `ship_tiers.json tiers[].sprite`로 배 그림을 고른다.
- 이유: `ShipTierUp`은 바뀌는 순간에만 나온다. 앱을 켠 직후·기록 재생(데모·부하·골든)에서는 지금 등급을 알 수 없다.
- 호환: 선택 필드 → 기존 기록 호환. `BattleView`는 세이브에 없음.

## 처리 결과 (S1, 2026-10-14)
- 받지 않는다. 배 등급은 `BattleView.stage`(이미 계약, 기록 재생에도 있음) + `tables.shipTiers.tierAt(stage)`로 정해지는 파생값이라,
  필드를 하나 더 두면 둘이 어긋날 수 있다. 렌더가 매 프레임 stage로 등급을 구하고, 바뀌는 순간(또는 `ShipTierUp`)에 연출한다.
- 해역 보스 판정도 같은 식으로 `tables.regions.regionAt(stage).regionBoss`·`bossAt(stage)`와 `BossSpawned.kind`를 쓴다.
