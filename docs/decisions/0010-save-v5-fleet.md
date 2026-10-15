# ADR-0010: 수동 편성 + 세이브 v5 `fleet`

- 날짜: 2026-10-15 · 상태: 채택 · 결정: 사용자(S1 경유) · 구현: economy(S2)

## 배경
설계서 4.3·4.8은 ‘출전은 파워 순 자동’이었다. 사용자는 출전을 직접 고르고 싶어 한다(좋아하는 선원, 보스 약점 계열).

## 결정
- 출전은 **기본 수동 편성**. ‘자동 편성’ 버튼(`AutoFleet`)이 기존 자동 규칙(파워 순, 같은 계열 `skills.maxSameFamilyInFleet`명까지)으로 한 번에 채운다.
- `GameState.fleet: List<String?>` — 슬롯 순서, null = 빈 칸. `fleetInit: bool` — 한 번이라도 편성됐는가.
- 명령 `SetFleetSlot(slot, crewId?)`: 다른 칸의 같은 선원과는 자리 바꿈, 미보유·슬롯 밖은 무시, 같은 계열 상한 초과는 거절 + 이벤트 `FleetRejected(slot, crewId, reason: 'family')`.
- 출전 판정은 `activeFleet(state, tables)` 하나: 배 등급 슬롯 수만큼 앞 칸, 빈 칸·미보유 제외. 전투·보스 카드(출전 선원)·오프라인·상자 추정이 모두 이것을 쓴다. 운영자 `OpSetFleet`(고정 편성)은 그대로 우선.
- 배 등급이 올라 슬롯이 늘면 **빈 칸으로 둔다**(사용자 선택). UI 배지는 `emptySlotCount`(쉬는 보유 선원이 있을 때 채울 수 있는 빈 칸 수).
- 환생으로 슬롯이 줄면 앞 칸만 출전하고 뒤 칸 기록은 남긴다(배 등급이 돌아오면 다시 출전).
- 새 게임·옛 세이브: `fleetInit == false`면 경제가 첫 틱에 자동 편성으로 채운다(새 게임 = 시작 선원 2명, 옛 세이브 = 기존 체감 유지).

## 세이브
- v4→v5 마이그레이션: `fleet: []`, `fleetInit: false`.
- 픽스처 `test/fixtures/saves/v5.json`: v4를 코덱으로 올린 뒤 빈 칸이 있는 편성(`manta, pingu, null, octo`)으로 다시 씀.

## 결과
- sim 가상 플레이어는 선원 상태가 바뀔 때마다 `AutoFleet` — 기존 지표 그대로(계속 접속 20명 × 3시간 비교).
- 설계서 4.3·4.8·출전 문구 갱신. UI(편성 화면·자동 편성 버튼·배지)는 ui 레인(S4).
