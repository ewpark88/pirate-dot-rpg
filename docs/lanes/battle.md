# 레인: 전투 코어 (battle) — S1 선장

- 브랜치: `main` (S1은 통합 세션을 겸한다) · 진척: `docs/PROGRESS.md`의 battle 행 + 세션 로그
- 소유 경로: `LANES.yaml` → `lanes.battle.paths`
- 설계서: 4.1 코어 루프, 4.3 계열 표, 4.4 핵앤슬래시 전투, 4.8 상한·계산 규칙

## 목표
`BattleSystem`(`packages/game_core/lib/src/battle/battle_system.dart`)을 채워 화면 없이 전투가 끝까지 돈다.

## 기다리지 않고 쓰는 입력
- 계약: `contracts.dart` (`GameState.battle`, `BattleView`, `EnemyView`, `FleetSlot`, 전투 이벤트)
- 테이블: `skills.json`, `waves.json`, `regions.json` (이 레인 소유), `ship_parts.json`의 `caps`(읽기만)
- 경제 수치(공격력·치명타 등)는 `EconomySystem`이 아직 없으면 테이블 공식으로 직접 계산하는 임시 함수를 둔다

## 할 일 (M1 → M3)
1. 무리 생성: 한 파 = `waves.mobCountAt(stage)`, 파 HP 풀 = 단일 HP × 마리 수 × `waveHpPoolFactor`, 해역별 적 종류
2. 적 이동(오른쪽 → 왼쪽), 배에 닿으면 `ShipDamaged`
3. 자동 편성: 파워 순, 같은 계열 최대 `maxSameFamilyInFleet`, 슬롯 수 = 배 등급
4. 계열별 기본 공격 8종(범위 모양은 `skills.json`), 피해 공식(설계서 4.8 곱셈 5항 고정), 범위 6마리 초과 50%, 연쇄 감소
5. 동시 처치(0.5초 창) → `MultiKill`, 함성 게이지 → 궁극기, 히트스톱 이벤트
6. 보스: 3파 후 등장, 30초 타이머, 실패 → 파밍(`farming=true`), `ChallengeBoss`로 재도전, 클리어 → 다음 스테이지 + 젬
7. `game_cli export-events` 실제 엔진 출력 → `fixtures/events/*.jsonl` 갱신(렌더 레인 통지)
8. M3: 스킬·궁극기 8계열, 해역 보스

## 완료 기준
- `scenarios/boss_timeout_farming.yaml`의 `skip` 제거 후 통과 + 수용 기준별 시나리오 추가
- 숫자 리터럴 0개(check), 같은 시드 → 같은 결과(리플레이 테스트)
- 운영자 명령 처리: `OpJumpStage`, `OpSetWave`, `OpSpawnBoss`, `OpSetInvincible`, `OpCastSkill`, `OpZeroCooldown`, `OpSetFleet`

## 통합 담당(S1)으로서
- 매일 머지 순서: 경제 → 렌더 → UI (머지마다 `tool/check.bat`)
- `docs/contracts/requests/` 요청서 처리 → 계약 변경 시 `contracts.dart` + 픽스처 + ARCHITECTURE 갱신
- 설계서 변경은 같은 날 `docs/GAME_DESIGN.md`에 반영
