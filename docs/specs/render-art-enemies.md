# 스펙 초안: 적·보스 스프라이트 채우기 (art, S3)

- 상태: 초안 2026-10-15 — S1 승인 대기. 기준: battle_ship.gif / 도트 팩 v0.2·전투 v0.3 스타일.
- 지금 커버리지: 적 27종 중 6(crab·gull·jelly·piranha·puffer·urchin), 보스 13 중 1(enemy_ship). 없는 건 렌더가 역할 색 플레이스홀더로 그린다.
  `pb_v0.26_patch`에는 적이 없다(배 손상 FX뿐) → 직접 그린다.

## 규격 (팩 실물 측정)
- 적: 2프레임 가로 시트, 한 프레임 11~17 × 8~12px, 칠한 색 3 + 외곽선 (27,23,38), 발밑 기준, 4fps. 예: crab 32×12(16×12 ×2), gull 26×8.
- 보스 배: enemy_ship 62×48 한 장(9색). 생물 보스는 48~64px 한 장 + 출렁임(렌더가 함).
- 생성: `tools/art/gen_enemies.py` — gen_ui_icons.py처럼 칠한 칸 격자 → 자동 1px 외곽선 → PNG, `--check`로 다시 굽기 같은 바이트, LICENSES OWN.
  2번째 프레임 = 다리·지느러미·날개 한 칸 바꿈(팩과 같은 방식).

## 일을 줄이는 방법: 실루엣 9개 + 변형 12개
| 새 실루엣 (손으로) | 변형 (팔레트 바꿈 + 장식 1~2칸) |
| --- | --- |
| flyingfish | — |
| penguin, seal | — |
| starfish | starfish_small(작게 다시 그림) |
| lavaturtle | — |
| angler, squid, siphon, eel | — |
| skeleton, wraith | — |
| (crab 기반) | icecrab·icecrab_small, lavacrab·lavacrab_small |
| (gull 기반) | stormgull, snowgull, firebird, cursegull |
| (jelly 기반) | ghostjelly(반투명 느낌 색 + 눈) |

`_small` 3종은 축소가 아니라 작은 격자로 다시 그린다(도트는 비정수 축소 금지).

## 순서 (처음 만나는 순서 = 해역 순)
1. **해역 1 산호초(1~50)의 남은 것** — 보스만 남음: `raider_ship`(중간 보스, enemy_ship 색·돛 바꿈) · `giant_hermit`(해역 보스, 소라게 생물 64px). 처음 몇 분에 보이므로 맨 먼저.
2. 폭풍해(51~): flyingfish, stormgull + 보스 storm_pirate(배 변형), thunder_ray
3. 빙하(101~): icecrab(+small), penguin, seal, snowgull + icebreaker, iceberg_walrus
4. 화산(151~): lavacrab(+small), starfish(+small), lavaturtle, firebird + fire_pirate, lava_whale
5. 심연(201~): angler, squid, siphon, eel + deep_sub, kraken
6. 유령(251~): skeleton, ghostjelly, cursegull, wraith + ghost_ship, ghost_admiral

한 묶음 = 한 해역. 묶음마다: 시트 미리보기(×8) + 그 해역 전투 장면 골든/비교 이미지 → S1 승인 → 커밋.
배 보스 5종(raider·storm_pirate·icebreaker·fire_pirate·ghost_ship)은 enemy_ship 격자를 바탕으로 색·돛·장식만 바꿔 빠르다. 생물 보스 6종이 제일 큰 일.

## 수용 기준
- `sprites_test`: 해당 해역의 적·보스가 모두 SpriteBank에 있다(플레이스홀더 0).
- 시트 크기·프레임 수가 규격대로(import 검증과 같은 규칙), `python -I tools/art/gen_enemies.py --check` 통과.
- 해역 장면 비교 이미지에서 같은 해역의 팩 적(예: crab)과 나란히 놓아도 선 굵기·색 수·명암 방향(왼쪽 위 밝음)이 같다.

## 물어볼 것 (S1)
- Q1 순서: 보스(raider_ship·giant_hermit)를 폭풍해 적보다 먼저 해도 되나? (추천: 예 — 첫 50스테이지 안에 나온다)
(pubspec은 `assets/enemies/`·`assets/bosses/` 폴더째 등록돼 있어 새 파일은 등록 요청 없이 읽힌다.)
