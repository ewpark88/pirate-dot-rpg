# 계획: 렌더 — 적 상태 표시 (감속·화상·취약)

- 스펙: `docs/specs/render-status.md` (**승인 대기**) · 계약 요청: `docs/contracts/requests/render-status.md` · 레인: render(S3)

## 단계
- [ ] 0. 스펙 승인 · 계약 F 결정 (main 반영)
- [ ] 1. fx_map `status` + 모델
- [ ] 2. 테스트 먼저: 수용 기준 1~4
- [ ] 3. EnemyPose 상태 필드, 그리기(색조 필터·불꽃·화살표, 머리 위 한 줄 배치)
- [ ] 4. `tool\check.bat --full` → 커밋

## 검증 방법
`tool\check.bat --full`, `flutter test apps/game/test/render`.
