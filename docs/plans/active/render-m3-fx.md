# 계획: 렌더 M3 — 스킬·궁극기·적 역할 연출

- 스펙: `docs/specs/render-m3-fx.md` (**승인 대기**) · 계약 요청: `docs/contracts/requests/render-m3-events.md` · 레인: render(S3)

## 목표
엔진 M3 이벤트(SkillCast·계열별 궁극기·분열·부활·장판·기절)를 데이터로 정한 연출로 그린다. 엔진 전에는 고정 기록으로.

## 단계
- [ ] 0. 스펙 승인 · 계약 요청 A·B·C 결정
- [ ] 1. `fx_map.json`: `skillFxScale`, `ultimates`(8종 패턴), `enemyLook`(역할별 색·크기), `zone` + `render_tables.dart` 모델·검증
- [ ] 2. 테스트 먼저: 수용 기준 1~9 → 실패 확인
- [ ] 3. 스킬 시전·화면 스킬(임시 어댑터 포함)
- [ ] 4. 궁극기 패턴 sweep·rain·strikes·volley
- [ ] 5. 슬롯 스킬 막대, 적 역할 모양, 분열·부활 감지
- [ ] 6. 장판(임시 어댑터 → ZoneSpawned), 기절 별(계약 B 후)
- [ ] 7. 골든 `battle_m3.png` → 승인 → `tool\check.bat --full` → 커밋

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`.

## 메모
- 파일 300줄: 궁극기 패턴은 `scene/ultimate_patterns.dart`, 적 모양은 `paint/enemy_look.dart`로 분리.
