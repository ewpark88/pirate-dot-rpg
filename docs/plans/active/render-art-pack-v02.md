# 계획: 아트 팩 v0.2 적용 준비

- 스펙: `docs/specs/render-art-pack-v02.md` (**승인 대기**, Q1 작업 위치·Q2 pubspec 결정 필요) · 레인: art + render (S3)

## 단계
- [ ] 0. 스펙 승인 · Q1(lane/art worktree) · Q2(pubspec assets) 결정
- [ ] 1. (render) 테스트 먼저: 수용 기준 4·5 → 스프라이트 뱅크 주입 테스트
- [ ] 2. (render) `SpriteBank` + 그리기(nearest·필터·시트 프레임), `BattleGame.useSprites`
- [ ] 3. (art) `tools/art/import_pack.py` + overrides + 크기 검증, 수용 기준 1·3
- [ ] 4. (art) 에셋 가져오기 + `LICENSES.json` → check 통과(수용 기준 2)
- [ ] 5. 골든 `battle_sprites.png` → 승인 → 부하 장면 성능 비교 기록 → 커밋

## 검증 방법
`tool\check.bat --full`, `python tools/art/import_pack.py --check`, 눈 확인 `flutter run -d chrome`.
