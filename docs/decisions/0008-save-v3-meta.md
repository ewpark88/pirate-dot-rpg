# ADR-0008: 세이브 v3 — 일일 '받음' 기록, 튜토리얼 단계 / 전장에 stage·보물상자

- 날짜: 2026-10-14 · 상태: 채택 · 요청: `docs/contracts/requests/ui-m3-meta.md` (ui S4, A1~A6), `render-stage.md` (render S3, D)

## 결정
- 세이브 v3: `daily.questsClaimed`(받은 퀘스트 id), `daily.attendanceClaimed`(오늘 출석 받음), `tutorialStep`(int?, 새 게임 1, null = 끝/건너뜀).
  마이그레이션 v2→v3: 빈 집합·false·null(기존 세이브는 튜토리얼을 끝낸 것으로 본다).
- 전장(BattleView, 세이브 밖): `stage`(기록 재생에서도 해역 배경), `chest`(ChestView x·y·ticksLeft — 경제 레인이 띄우고 치움, 전투는 그대로 이어 준다). `BattleView.copyWith` 추가.
- 명령: `SkipTutorial`, `TutorialAck(step)`, 운영자 `OpSpawnChest`, `OpSetTutorial(step?)`, `OpGrantTailwind(duration)`. 처리(규칙)는 경제 레인.

## 결과
- 픽스처 `test/fixtures/saves/v3.json` 추가, v1·v2는 마이그레이션 검증용으로 유지.
