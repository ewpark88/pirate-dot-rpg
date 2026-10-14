# 계획: 전투 기록 재생 + 타격감 (render, M2 1단계)

- 스펙: `docs/specs/render-battle-replay.md` (승인됨 2026-10-14, S1) · 레인: render(S3)

## 목표
Flame `BattleGame`이 합성 전투 기록을 재생해 배·적·발사체·이펙트·데미지 숫자·타격감을 그린다(아트 전 단색 플레이스홀더).

## 단계
- [x] 0. 스펙 승인 (2026-10-14, S1 위임)
- [x] 1. `render_tables.dart` 확장(juice 전체 + fx_map `projectiles`), `fx_map.json`에 계열 8종 스타일 추가
- [x] 2. `render/demo/sample_battle.g.dart` — S1이 export-events로 쓸 예정. 데모가 먼저 필요하면 fixture 사본으로 임시 생성(수용 기준 11)
- [x] 3. 테스트 먼저: 수용 기준 1~9·11 단위 테스트 작성 → 실패 확인
- [x] 4. `RecordingPlayer`(보간·lookahead·히트스톱·반복 + 라이브 push 모드, S1 요청) — 순수 Dart
- [x] 5. 풀 + 상한(`FxPool`, `DamageNumberLayer`)
- [x] 6. Flame 컴포넌트: 배·적·발사체·이펙트·숫자·흔들림 카메라, `JuiceSettings`
- [x] 7. `BattleGame(recording:, juice:, settings:)` 조립, 골든 1장(수용 기준 10)
- [x] 8. `tool\check.bat --full` → 진척·계획 갱신 → lane/render 커밋

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`, 눈 확인은 `flutter run -d chrome`(데모 기록 상수로).

## 메모
- S1 답변으로 Q1(히트스톱 프레임)·Q2(데모 기록 경로) 해결 — 스펙의 결정 기록 참고.
- 파일 300줄 상한 → render/ 아래 replay/, fx/, juice/, components/로 나눈다.
- 렌더는 ui/·adapters/를 import하지 않는다(check가 막음). `BattleGame` 생성자를 바꾸면 `home_screen.dart`(UI 레인)가 깨지지 않게 기본값을 둔다.
