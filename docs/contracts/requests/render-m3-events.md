# 계약 변경 요청: render-m3-events (render → S1)

- 요청: S3 render · 2026-10-14 · 관련 스펙: `docs/specs/render-m3-fx.md`, `docs/specs/battle-m3-skills.md`
- 상태: 제안 (S1 결정 대기). 결정 전에는 렌더가 임시 어댑터로 계속한다(스펙 규칙 2·5·9).

## A. `SkillCast`에 범위 표시 + 원 여러 곳
- 추가 필드: `scope` (`'normal'` | `'screen'`, JSON 생략 시 `'normal'`). 전설 이상 화면 스킬이면 `'screen'`.
- `shape: circle`·`count > 1`처럼 중심이 여러 곳이면 중심마다 `SkillCast`를 하나씩 낸다(x,y = 중심).
- 이유: 렌더는 선원 등급을 모른다(`FleetSlot`에 등급 없음). 화면 전체 연출 여부를 추측하면 틀릴 수 있다.

## B. `EnemyView.stunned` (bool, 기본 false)
- 기절 중이면 true. JSON 생략 시 false → 기존 기록 호환.
- 대안: `stunTicksLeft` (int). 렌더는 bool이면 충분.
- 이유: 기절은 "같은 위치"만으로는 히트스톱·정지와 구별되지 않는다. 머리 위 별 표시용.

## C. 장판 이벤트 `ZoneSpawned`
```
ZoneSpawned(tick, {crewId, x, y, radius, ticks})   // JSON type: 'zoneSpawned'
```
- 수중 장판이 생길 때 한 번. 끝은 `ticks`로 렌더가 센다(종료 이벤트 불필요).
- 이유: 지속 피해는 Damage만 반복되므로 장판 위치·반경·남은 시간을 알 수 없다.

## 호환
- 모두 선택 필드/새 이벤트라 기존 `fixtures/events`·세이브와 호환. `GameEvent.fromJson`의 미지 타입 처리(`_metaEventFromJson`)에 `zoneSpawned` 추가 필요.
