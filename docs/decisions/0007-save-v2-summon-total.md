# ADR-0007: 세이브 v2 — 누적 소환 횟수(summon.total)

- 날짜: 2026-10-14 · 상태: 채택 · 요청: `docs/contracts/requests/economy-tutorial-summon.md` (economy S2)

## 맥락
설계서 4.9·4.12의 "첫 10연 무료 + 영웅 1장 확정"을 하려면 무료 10연을 이미 썼는지 기억해야 한다.
`pityCount`는 영웅 이상이 나오면 0으로 돌아가서 쓸 수 없다. sim에서 첫 소환이 6.1분(목표 5분 이내)이다.

## 결정
- `GameState.summonsTotal`(세이브 `"summon": {"pityCount", "total"}`) 추가, 스키마 v2.
- 마이그레이션 v1→v2는 `total: 0`. 출시 전이라 실제 플레이어 세이브가 없으므로, v1 세이브도 무료 10연을 한 번 받는 것을 허용한다
  (요청서의 "collection이 시작 선원보다 많으면 10" 추정은 마이그레이션이 테이블을 볼 수 없어 쓰지 않는다).
- 무료 10연 규칙(젬 0, `tutorial.firstTenGuarantee` 확정, total 증가)은 경제 레인이 `Summon` 처리에서 구현한다.

## 결과
- 픽스처 `packages/game_core/test/fixtures/saves/v2.json` 추가(`dart run game_cli fixtures --saves`), v1.json은 마이그레이션 검증용으로 유지.
