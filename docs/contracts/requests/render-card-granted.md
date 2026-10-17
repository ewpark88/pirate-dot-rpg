# render: 카드 획득 이벤트 CardGranted (사용자 피드백 #17 '언제 선원을 얻는지 보여야')

- 요청 레인 / 날짜: render(S3) / 2026-10-17
- 바꿀 계약: GameEvent 추가 `CardGranted` (economy `receiveCard`가 낸다)

## 왜 필요한가
- 보스 처치 카드(`grantBossCards`)·오프라인 카드는 상태만 바꾸고 이벤트가 없다 → 렌더는 누구 카드인지·등급을 모른다.
- #17: 카드가 금화처럼 보스 자리에서 튀어나와 배로 날아가 모이게(선원 초상 + 등급 색 테두리). 렌더 쪽 자리는 이미 있다:
  `TopBossLoot.card(crewId, color)` (28318974).
- 처음 얻는 선원은 더 크게(새 선원!) 보여 주고 싶다 → `isNew`.

## 제안 (코드 스케치)

```dart
/// 카드 한 장을 받았다 — [source] 'boss'·'offline'·'starter'. [isNew]면 처음 얻은 선원(도감에 추가).
class CardGranted extends GameEvent {
  const CardGranted(super.tick, {required this.crewId, required this.rarity, required this.source, this.isNew = false});
  final String crewId;
  final String rarity; // rarities.json id
  final String source;
  final bool isNew;
}
// cards.dart receiveCard(...) 를 부르는 곳(grantBossCards·offline)에서 ctx.emit(CardGranted(...)).
// 같은 틱에 BossCleared와 함께 나오면 렌더가 그 보스 터짐에 카드를 붙인다(Kill → BossCleared → CardGranted 순서면 가장 좋다).
```

## 그동안 쓰는 임시 어댑터
- 없음 — 카드 없이 금화·젬만 터진다. 이벤트가 오면 `case CardGranted(): scene.topHits.loot.card(e.crewId, 등급 색)` 한 줄.

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
