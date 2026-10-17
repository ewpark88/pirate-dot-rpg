# render: 방치 단계·발열 단계를 BattleGame에 넘겨 주기 (S4 battle_providers.dart)

- 요청 레인 / 날짜: render(S3) / 2026-10-17
- 바꿀 계약: 계약 변경 없음 — S4 소유 `apps/game/lib/ui/state/battle_providers.dart`에 연결 두 줄

## 왜 필요한가
- IdleGate(S4)가 `idleLevelProvider`를 만들었지만 아무도 `game.idle.follow`를 부르지 않는다 → 렌더는 아직 자기 전역 포인터로 따로 센다.
  UI 절전 기준(설정 powerSave일 때만 3분)과 렌더 기준(fx_map frameCap.dimSec 3분, 늘)이 달라 UI 덮개 없이 렌더만 어두워질 수 있다.
- 발열 단계(`thermalLevelProvider`, main)는 주사율·효과음만 바꾸고 렌더 그리기는 그대로다.
  렌더는 이제 `game.idle.heat`(int, ThermalLevel.index)를 받는다: 보통(2)↑ 가벼운 그리기, 심함(3)↑ 효과음 예산 절반.

## 제안 (코드 스케치)

```dart
// battle_providers.dart, battleGameProvider 안 (render는 ui를 import할 수 없어 UI가 이어 준다)
import 'package:pirate_dot/render/battle_game.dart' as render show IdleLevel;

ref
  ..listen(idleLevelProvider, (_, l) => game.idle.follow(switch (l) {
        IdleLevel.active => render.IdleLevel.active,
        IdleLevel.idle => render.IdleLevel.idle,
        IdleLevel.sleep => render.IdleLevel.dim,
      }), fireImmediately: true)
  ..listen(thermalLevelProvider, (_, t) => game.idle.heat.value = t.index, fireImmediately: true);
```

## 그동안 쓰는 임시 어댑터
- 연결 전엔 렌더가 스스로 센다(전역 포인터, 60초 idle·180초 dim). 발열은 0으로 본다.

## 처리 결과 (S1 작성)
- [x] 반영 — S4 lane/ui 936b67f8(battleGameProvider에서 idle.follow·idle.heat 연결), main 머지는 S4 골든 수정과 함께
