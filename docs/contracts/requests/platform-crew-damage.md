# platform: 선원별 피해 집계 — 사용자 피드백 #13·#14 (BattleView.crewDamage · BossCleared.crewDamage/mvp)

- 요청 레인 / 날짜: platform(S5) / 2026-10-17 · 계획: docs/plans/active/user-feedback-2026-10-17.md
- 바꿀 계약: `packages/game_core/lib/src/engine/battle_view.dart`(필드 1), `events_stage.dart` BossCleared(필드 2, 선택 키). 엔진 집계는 `battle/combat.dart` strike 한 곳 + field.

## 지금 계약으로 되는가 — 확인 결과
- **거의 된다**: 모든 선원 피해는 `Round.strike` 한 곳을 지나고 `Damage(targetId, amount, crewId)`가 나온다(일반 발·관통·장판·빔·화상·전설 폭발·출격·피버 첫 일격 = 선장 id).
  crewId가 없는 피해: 피버 오라 맥동(top_fever) · 자폭 적 폭발(top_bomber) · 빠른 항해 자동 처치(fast_sail) → 선원 몫이 아님, 빼면 된다.
- 그래도 계약을 넓히자는 이유
  1. **넘친 피해(overkill)**: `Damage.amount`는 남은 HP로 자르지 않는다(렌더 큰 숫자용). 마지막 한 방·궁극기형 일격이 몇 배로 부풀어 보스전 합이 보스 최대 HP를 넘고 MVP가 '막타'로 쏠린다.
  2. UI가 보스 id를 따라가야 한다: `BossSpawned`에 enemyId가 없고, 분열(BossSplit)·순환으로 보스 몸이 바뀐다 → UI가 엔진 규칙을 다시 짜게 된다.
  3. 보스 처치 창(#14)은 BossCleared 순간에 확정 값이 있어야 한다 — 이벤트 흐름을 놓친 화면(탭 전환 중)도 같은 값을 보게.

## 제안 (최소)
```dart
// battle_view.dart — 전송용, 세이브 안 함(BattleView 그대로)
final Map<String, BigNum> crewDamage; // 이번 스테이지 시작부터 선원별 실제 피해(남은 HP로 자름). 스테이지가 바뀌면 0.

// events_stage.dart — 선택 키(옛 기록 호환: 없으면 빈 맵·null)
class BossCleared {
  final Map<String, BigNum> crewDamage; // 이번 보스전(보스·분열 몸·촉수 포함) 선원별 실제 피해
  final String? mvp;                    // 가장 큰 crewDamage (같으면 출전 칸 순서 앞)
}
```
- 엔진(S5가 구현, review 브랜치): `strike`에서 `dealt = min(amount, e.hp)`를 crewId별로 field 맵 두 개(스테이지·보스전)에 더한다. Damage 이벤트는 그대로(amount 안 자름).
- 결정론·sim 불변: 기록만 늘고 판정·난수는 그대로. 골든 fixtures/events의 bossCleared 줄이 늘어나는 정도.
- UI(S4): #13 = `battle.crewDamage`로 선원 칸에 피해·비율 막대, #14 = BossCleared 받으면 선원별 보스 피해 창 + MVP.

## 그동안 쓰는 임시 어댑터
- S4는 지금 바로 `Damage` 이벤트를 crewId별로 더해 #13 화면을 만들 수 있다(넘친 피해 포함 — 합/비율 표시는 대체로 맞음). 계약이 들어오면 `battle.crewDamage`로 바꾼다.
- #14는 계약 뒤가 깔끔하다(임시로는 BossSpawned ~ BossCleared 사이 Damage 합, 넘친 피해 포함).

## 처리 결과 (S1 작성)
