# platform: EnemyView.rooted — 물기 속박(bara) 2초 표시 (선원 정리 2안, S3 연출)

- 요청 레인 / 날짜: platform(S5) / 2026-10-17 · 엔진: review/crew-traits-2 (battle/crew_traits2.dart, Foe.rootTimer)
- 바꿀 계약: `packages/game_core/lib/src/engine/battle_view_items.dart` EnemyView 선택 키 1(`rooted`, bool, 기본 false면 JSON에 없음)

## 왜
- 물기 속박은 맞은 적이 bindSec(2초, 신화 2.5) 동안 움직이지 못하는 상태다. 렌더(S3)가 지속 표시(이빨 자국·사슬)를 하려면
  지금 속박 중인지 알아야 한다. 이벤트만으로는 끝나는 시점을 모른다(보스는 bossControlFactor배로 짧고, 다시 물면 늘어남).

## 제안
```dart
// battle_view_items.dart — EnemyView
final bool rooted; // 물기 속박 중(Foe.rootTimer > 0). 기본 false면 JSON에 키가 없다(옛 기록 그대로).
// foe.dart view(): rooted: rootTimer > 0
```
- 결정론·sim 불변(표시용). 골든 fixtures/events는 속박이 있는 기록만 줄이 늘어난다.

## 그동안 쓰는 임시 어댑터
- S3: 맞은 순간 이빨 자국만 0.5초(Damage crewId == bara).

## 처리 결과 (S1 작성)
