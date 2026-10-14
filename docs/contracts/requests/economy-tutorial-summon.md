# economy: 첫 10연 무료 소환 여부를 세이브에 기록

- 요청 레인 / 날짜: economy (S2) / 2026-10-14
- 바꿀 계약: `GameState`(세이브 v1 `summon` 객체) — 필드 추가, 세이브 v2 + 마이그레이션 + 픽스처

## 왜 필요한가
설계서 4.9(첫 10분 대책)·4.12 튜토리얼 4단계: "첫 10연 무료 + 영웅 1장 확정". `meta.json tutorial.firstTenSummonFree`도 있다.
sim에서 첫 소환 가능이 6.1분(목표 5분 이내, 7.2)이고, 무료 10연이 있으면 첫 보스 처치 직후(약 1분)가 된다.
그런데 무료 10연을 이미 썼는지 기억할 곳이 상태에 없다(`pityCount`는 영웅 이상이 나오면 0으로 돌아간다).

## 제안 (코드 스케치)

```dart
// GameState
final int summonsTotal; // 누적 소환 횟수. 세이브: "summon": {"pityCount": n, "total": n}
// v1 → v2 마이그레이션: total = 0 이면 기존 플레이어도 무료 10연을 받는다 → 대신 collection.length > startingCrews 이면 10으로 채운다
```
경제는 `Summon(count: 10)`이고 `summonsTotal == 0`이면 젬을 받지 않고, 결과 중 하나를 `tutorial.firstTenGuarantee` 이상으로 확정한다.

## 그동안 쓰는 임시 어댑터
없음 — 무료 10연은 반영하지 않고 sim 지표 ‘첫 소환 가능’은 벗어남으로 둔다.

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
