# 스펙: 아트 팩 v0.2 적용 준비 (art 레인 2단계 + 렌더 스프라이트 로더)

- 상태: 초안 — 승인 대기 · 레인: art(에셋·도구) + render(로더·그리기) — 둘 다 S3 · 설계서 절: 10장 아트·사운드 조달, 6.3 라이선스 검사
- 파일 이름 메모: `docs/specs/art-*`·`apps/game/assets/`는 art 레인 소유라 `lane/render`에서 쓸 수 없다. 이 스펙은 렌더 이름으로 두고,
  에셋 작업은 `lane/art` 브랜치(worktree)에서 한다(아래 결정 필요).

## 목적
- 시원한가: 단색 사각을 실제 도트(선원 초상·적·배·발사체·이펙트 시트)로 바꿔 M2 실기기 손맛 확인 때 "게임처럼" 보이게 한다.
- 단순한가: 원본 팩 zip → 스크립트 한 번 → `apps/game/assets/` + `LICENSES.json`. 손으로 옮기지 않는다(다시 굽기 가능).
- 피로가 없는가: 그림이 없는 것은 지금 플레이스홀더 그대로 — 부분 적용으로도 화면이 깨지지 않는다.
- 공정한가: 라이선스는 자체 IP(`OWN`)와 CC0·OFL·MIT만. 등록 안 된 파일은 check가 막는다.

## 입력 (원본, 저장소 밖)
| 팩 | 경로 | 쓰는 것 |
| --- | --- | --- |
| 도트 팩 v0.2 (32px) | `D:\Projects\이미지참고용\해적도트원정대_도트_v0.2_32px\pirate_dot_v0.2_32px.zip` | `characters/<id>.png` 선원 초상 40명(32×32), `fx/*.png` 이펙트 시트 8종(+`fx.json`) |
| 전투 v0.3 | `D:\Projects\이미지참고용\해적도트원정대_전투_v0.3\pirate_battle_v0.3.zip` | `sprites/` 배 1단계·적 6종·보스선·발사체 5종·코인 |

## 규칙
1. **에셋 배치**(`apps/game/assets/`, art 레인):
   - `crews/<id>.png` 32×32 — `crews.json`의 `portrait` 경로와 같다(40명 모두 있음).
   - `fx/<sheetId>.png` — `fx_map.json fxSheets`의 id·w·h·frames와 크기가 맞아야 한다(가로로 프레임).
   - `enemies/<kind>.png` 16px 안 — v0.3에 있는 6종(crab·jelly·fish·puffer·urchin·gull)만. 2프레임은 렌더가 1px 위아래 흔들기로 만든다.
   - `bosses/enemy_ship.png`, `ship/ship_t1.png`(약 60×46), `projectiles/<name>.png`(cannonball·bullet·harpoon·stone·torpedo), `coin.png`.
   - 없는 것(적 21종, 보스 12종, 해역 배경 6장, 발사체 shock·assault·air): 지금 플레이스홀더 유지. 커버리지 표를 진척 문서에 둔다.
2. **가져오기 도구**(`tools/art/import_pack.py`, art 레인): 두 zip을 풀어 규칙 1대로 복사·이름 바꿈 → 크기 검증(틀리면 실패) →
   `LICENSES.json` 갱신. `tools/art/overrides/<같은 경로>`가 있으면 그것을 우선(전설 8명 수작업 보정 자리). 두 번 돌려도 결과가 같다.
3. **라이선스**(`apps/game/assets/LICENSES.json`): 키 = `assets/` 아래 경로, 값 = `{"source", "license"}`.
   자체 IP 도트는 `"license": "OWN"`, `source`는 `"Pirate Busters v0.24 → 도트 팩 v0.2 (pirate_dot_v0.2_32px.zip:characters/octo.png)"`처럼 팩·zip 안 경로까지.
   폰트 Galmuri는 `OFL`, 효과음·BGM은 `CC0`만(이번 범위 밖). 손으로 고치지 않고 도구가 쓴다. check가 미등록·금지 라이선스를 막는다.
4. **pubspec 등록**: `apps/game/pubspec.yaml`은 레인 소유가 아니므로 S1에게 `flutter: assets:`에 폴더 6개(crews/ fx/ enemies/ bosses/ ship/ projectiles/ + coin.png) 추가를 요청한다.
5. **렌더 로더**(`render/sprites/sprite_bank.dart`, render 레인): id → `ui.Image`를 Flame `Images`로 미리 읽는다(로드 실패·없음 = 플레이스홀더).
   그리기는 nearest(`FilterQuality.none`)·정수 좌표, 흰 번쩍임은 흰색 `ColorFilter`, 물속 색조·반투명은 같은 필터로. 슬롯은 초상, 이펙트는 시트 프레임.
   `BattleGame`이 로드를 끝내기 전 프레임과 테스트(스프라이트 없음)는 지금 플레이스홀더 그대로 → 기존 골든 4장은 바뀌지 않는다.
6. **성능**: 스프라이트 그리기는 이미지 캐시 + `drawImageRect`. 부하 장면에서 프레임 시간을 플레이스홀더 대비 비교해 진척 문서에 남긴다.

## 수용 기준 (Given / When / Then)
1. Given 두 zip When `import_pack.py` 두 번 Then `apps/game/assets/` 결과가 같고, 크기 검증 통과(초상 32×32, 적 ≤16px, fx 시트 = fx_map 크기).
2. Given 가져온 에셋 When `tool\check.bat` Then 라이선스 검사 통과 — 모든 파일이 `LICENSES.json`에 `OWN` 등록.
3. Given `overrides/crews/octo.png` When 가져오기 Then 그 파일이 쓰인다.
4. Given 스프라이트가 없는 종류 When 그림 Then 플레이스홀더(기존 골든 4장 그대로 통과).
5. Given 스프라이트 뱅크(테스트용 단색 이미지 주입) When 적·초상·이펙트를 그림 Then `drawImageRect`로 그리고 번쩍임 필터가 적용된다(단위 테스트).
6. 골든 1장: 실제 팩 이미지로 그린 장면 `goldens/battle_sprites.png`(승인 필요, 테스트가 에셋을 읽을 수 있을 때).

## 문구
없음 — 크레딧 화면은 UI가 `LICENSES.json`으로 만든다(OFL 표기 필요 시).

## 운영자 모드
"스프라이트 끄기" 토글(플레이스홀더로 비교) — 값만 `BattleGame.useSprites`로 노출, 패널은 UI.

## 열린 질문 (S1)
- Q1. art 레인 작업 위치: `lane/art` worktree를 새로 만들지, 아니면 render 브랜치에서 art 경로를 잠시 허용할지(LANES.yaml).
- Q2. pubspec `flutter: assets:` 추가(규칙 4) — S1이 main에서.
- Q3. 원본 팩은 저장소 밖(`D:\Projects\이미지참고용`). 도구가 그 경로를 인자로 받는다 — 다른 PC에서 다시 굽기는 팩 zip 경로만 바꾸면 된다.
