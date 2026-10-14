# 계획: 전투 코어 M1

- 스펙: `docs/specs/battle-m1-core.md` (승인 2026-10-14) · 레인: battle (S1, main)

## 단계
- [x] 1. 테이블: `shock` 계열·선원 `skill` 필드, 발사 간격·배율·제외 층, `waves.field`, `boss.speed`, `rage.ultimateMultiplier`
      (+ 모델·검증·`import_crews.dart`·ARB `battleFamilyShock`)
- [x] 2. 테스트 먼저 (`packages/game_core/test/battle/`): 수용 기준 1~7, 10 단위 테스트 → 실패 확인
- [x] 3. 구현 `packages/game_core/lib/src/battle/`
      - `field.dart` 내부 시뮬 상태(적 HP·접촉 타이머·슬롯 쿨타임·동시 처치 창) ↔ BattleView 투영
      - `combat_stats.dart` 임시 전투 수치(대포·선체·돛·망루·화물칸, 선원 파워·등급)
      - `fleet.dart` 자동 편성 · `targeting.dart` 모양 8종 · `battle_system.dart` 흐름(파·보스·파밍·운영자)
- [x] 4. 시나리오: `boss_timeout_farming` skip 해제, `boss_clear_advances.yaml` 추가
- [x] 5. `game_cli export-events` 실제 엔진 출력 → `fixtures/events/sample_battle.jsonl` 갱신, 렌더 레인 통지
- [ ] 6. check `--full` → 진척 문서 → 커밋

## 메모
- 2026-10-14: 1~4 완료. 테스트를 구현보다 늦게 썼다(순서 위반) — 다음 단계부터 테스트 먼저.
- 새 플레이어 10분 프로브: 첫 보스 실패 약 1분 40초(목표 1~3분 안), 한 파 약 30초(느림 → sim으로 조정).
- 시작 선원 `meta.startingCrews`(옥토·톡) 추가, `GameState.newGame(crews:)`.
- 남은 것: 5(export-events 실제 출력), economy 머지 후 `combat_stats.dart` → `ShipStats.of`/`crewPowerMultiplier` 교체,
  보스 처치 시 `grantBossCards(s, ctx, fleet)` 호출(스테이지 올리기 전).
