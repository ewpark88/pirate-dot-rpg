# 계획: 렌더 성능 측정 준비 (render, M2 관문)

- 스펙: `docs/specs/render-perf.md` (**승인 대기**) · 레인: render(S3)

## 목표
실기기 60fps 판단용 부하 장면·프레임 측정·절전 30fps·정수배 확대를 렌더에 넣고, 운영자 패널이 쓸 값을 노출한다.

## 단계
- [ ] 0. 스펙 승인
- [ ] 1. 테스트 먼저: 수용 기준 1~6 → 실패 확인
- [ ] 2. `PerfMonitor`(링 버퍼, p50·p95·최대)
- [ ] 3. `stressRecording()` 결정론적 부하 기록
- [ ] 4. `BattleGame.loadStress/loadDemo/resumeLive`, `perf` 노출
- [ ] 5. 절전 Picture 재사용
- [ ] 6. 정수배 확대 뷰포트 (Q1 확인 후)
- [ ] 7. `tool\check.bat --full` → 진척·계획 갱신 → 커밋 → S4에 측정 절차 전달

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`, 눈 확인 `flutter run -d chrome`. 실기기 측정은 S4.
