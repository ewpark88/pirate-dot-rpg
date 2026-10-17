# 요청: 분노(rage) 잔재 정리 — 레인 밖 부분 (S2 → S1·S5)

- 배경: docs/specs/platform-fever-break.md 1절 '정리(S2)'. 궁극기·분노 게이지가 없어져 rage는 항상 0.
- S2가 레인 안에서 한 것: meta.json 즉석 도전 `ultimate`(minRage)·ambush `rage` 삭제, challenge.dart minRage 필터·궁극기 처치 집계 삭제, Field.ultimateKills 삭제.

## 레인 밖이라 요청하는 것
1. **skill_tables.dart (battle 소유)**: `rage {perKill, max, autoTrigger, ultimateMultiplier}` 파싱 → 피버 첫 일격이 쓰는 `ultimateMultiplier`만 최상위 키로(`skills.json "ultimateMultiplier": 5`). `ragePerKill`·`rageMax`·`rageAutoTrigger` 삭제. 바뀌면 S2가 skills.json의 `rage` 항목을 지운다.
2. **Progress.rage (세이브)**: 제안 = 읽기는 선택 키(`as num?`, 옛 세이브 v1~v7 그대로), 쓰기는 안 함 → 필드 삭제. dex·fever와 같은 '선택 키' 방식이라 스키마 버전은 그대로(마이그레이션 불필요). 세이브 픽스처는 손대지 않는다.
   단, toJson이 바뀌면 생성물 `fixtures/states/*.json`·`fixtures/events/sample_battle.jsonl`·`apps/game/lib/operator/sample_states.g.dart`와 `game_cli/lib/src/fixtures/{engine_battle,sample_states}.dart`의 `rage:` 인자를 바꿔야 함 → S1이 main에서 `game_cli fixtures` 재생성.
3. **BattleView.rage**: S4가 HUD 분노 게이지를 지운 뒤 삭제(그 전엔 항상 0). Round의 `rage` 인자·`TriggerUltimate` 명령(무시됨)도 같은 때 정리.

순서 제안: 1 → (S4 게이지 제거) → 2·3을 한 번에, 픽스처 재생성과 함께.
