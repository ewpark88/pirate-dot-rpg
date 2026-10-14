# 계획: 아트 팩 v0.2 적용 준비

- 스펙: `docs/specs/render-art-pack-v02.md` (승인됨 2026-10-14, S1 — Q1 render가 assets 소유, Q2 S1이 머지 때 pubspec) · 레인: art + render (S3)

## 단계
- [x] 0. 스펙 승인 · Q1(lane/art worktree) · Q2(pubspec assets) 결정
- [x] 1. (render) 테스트 먼저: 수용 기준 4·5 → 스프라이트 뱅크 주입 테스트
- [x] 2. (render) `SpriteBank` + 그리기(nearest·필터·시트 프레임), `BattleGame.useSprites`
- [x] 3. (art) `tools/art/import_pack.py` + overrides + 크기 검증, 수용 기준 1·3
- [x] 4. (art) 에셋 가져오기 + `LICENSES.json` → check 통과(수용 기준 2)
- [x] 5. 골든 battle_sprites.png(S1 승인 d3c03e1), 부하 장면 그리기 비용 비교 0b16bdb

## 메모
- 커밋: 11f3c8c 에셋 62개+LICENSES+도구, 4d537e1 SpriteBank·그리기.

## 검증 방법
`tool\check.bat --full`, `python tools/art/import_pack.py --check`, 눈 확인 `flutter run -d chrome`.
