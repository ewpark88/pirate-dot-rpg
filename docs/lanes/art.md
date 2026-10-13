# 레인: 아트 (art) — S3, 2단계(M3~M5)

- 브랜치: `lane/art` · 진척: `docs/progress/art.md`
- 소유 경로: `LANES.yaml` → `lanes.art.paths` (`apps/game/assets/`, `tools/art/`)
- 설계서: 10장 아트·사운드 조달

## 할 일
1. 도트 팩 v0.2 적용: 선원 초상 40명(32×32), 전설 8명 수작업 보정(`overrides/` 우선)
2. 배 4단계(약 60×46) + 부위별 외형 3단계, 적 20종(16px 안, 2프레임), 보스(약 48px), 해역 배경 6개(320×148, 3층)
3. 스킬·궁극기 이펙트 8종 추가, 팔레트 공유(불 5·물 5·전기 4·금 4색)
4. 폰트 Galmuri(OFL), 효과음·BGM(CC0만)
5. 다시 굽기 스크립트는 `tools/art/`(원본: `D:\Projects\이미지참고용`의 팩 zip 안 `tools/`)

## 완료 기준
- 모든 에셋이 `apps/game/assets/LICENSES.json`에 등록 (CC0·OFL·MIT·OWN 외 금지 — check가 막는다)
- 자체 IP(Pirate Busters 도트)는 `"license": "OWN"`
