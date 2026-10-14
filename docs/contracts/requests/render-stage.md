# 계약 변경 요청: render-stage (render → S1)

- 요청: S3 render · 2026-10-14 · 관련 스펙: `docs/specs/render-regions.md`
- 상태: 제안 (S1 결정 대기). 결정 전에는 `BattleGame.stage` 세터(기본 1)로 계속한다.

## D. `BattleView.stage` (int, JSON 생략 시 1)
- 지금 싸우는 스테이지. 렌더가 `regions.json fromStage`로 해역 배경을 고른다.
- 이유: 배경은 전투 화면의 일부인데 `BattleView`에 해역 정보가 없다. 기록(데모·부하·골든)만으로 해역을 재현하려면 프레임에 있어야 한다.
  UI가 따로 넣어 주는 방식은 라이브에서는 되지만 기록 재생에서는 해역을 알 수 없다.
- 호환: 선택 필드라 기존 `fixtures/events`·세이브와 호환(`BattleView`는 세이브에 들어가지 않음).
