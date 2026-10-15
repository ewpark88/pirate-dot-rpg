# 스펙 초안: 선원 일러스트 — Pirate Busters 디자인 차용 (art, S3)

- 상태: 시안(3명 + 등급 테두리) — 사용자·S1 확인 대기. 2026-10-15.
- 사용자 결정(S3 세션에서 직접): "pirate-busters의 디자인을 차용하면 될 것 같은데 굳이 새로 만들기까지 하니?"
  → **이미지 생성(Figma AI 등) 하지 않는다.** 같은 IP(Pirate Busters, 자체 IP — 도트 팩 v0.2의 원본)의 기존 그림을 가져온다.

## 원본 (D:\Projects\pirate-busters\art\pb_v0.24_main\ + v0.25·v0.26 패치)
- 캐릭터 40명 — 우리 crews.json 40명과 **id가 모두 같다**(빠짐·남음 0).
  - `characters/<id>/<id>_blue.svg` 원본(240×324, 발 120,315), 표정 6종 `expr/`.
  - `png/characters/<id>/<id>_blue_card@2x.png` 355×480 — 카드 그림 창용으로 이미 크기 맞춤(scale .74).
  - `png/ui/portraits/<id>_blue@1x·2x·3x.png` — 얼굴 초상(정사각, @3x 323~374px).
  - `png/characters/<id>/<id>_blue_battle@1x·2x·3x.png` — 작은 전투 그림(22×30 @1x).
- 카드 등급 테두리: `png/ui/cards/card_{common,rare,hero,legend,mythic}_{back,front}@1x·2x·3x.png`(504×716 @2x),
  전설 `card_legend_rays`, 반짝 `card_sparkle`(48px)·`card_shine`, 배치 `ui/cards/cards.json`(그림 창 12,12–228,250, 이름·등급 리본 자리).
  신화는 오로라·삼지창·무지개 테두리(v0.22 신화 등급).
- 화풍: 약 2.5등신 SD, 굵은 어두운 외곽선, 해 질 녘 역광, 가죽·금속 장비, 중간 톤(귀여움과 사나움 사이) — 원본 README 그대로.
- 팀 색 `blue`를 쓴다(우리 편). `red`는 적 진영용이라 쓰지 않는다.

## 쓰는 곳 (제안)
| 화면 | 그림 | 크기 |
| --- | --- | --- |
| 선원 카드(선원 탭 목록·소환 결과) | 등급 back + `_card@2x` + 등급 front (+ 전설 rays·sparkle, 신화 front 홀로) | 카드 504×716 @2x, 목록은 줄여서 |
| 선원 상세 | 같은 카드 또는 `_blue.svg`를 크게, 표정 6종 | 상세 크기 |
| 전투 선원 슬롯(32px 도트 초상) | 그대로 도트 유지 또는 `portraits` 축소 — **B(전투 HD) 결정과 함께** | — |

## 가져오기 (다음 단계, 승인 후)
- `tools/art/import_pb.py`(새로): 위 경로에서 40명 `_card@2x`·`portraits@2x`·카드 테두리 5등급만 `apps/game/assets/crew_art/`·`assets/ui/cards/`로 복사,
  크기 검증, LICENSES.json `{source: "Pirate Busters 자체 IP → art/pb_v0.24_main/<경로>", license: "OWN"}`, `--check` 다시 굽기 같음.
- pubspec에 `assets/crew_art/`·`assets/ui/cards/` 등록은 S1. 화면에 붙이는 건 S4(UI).
- 앱 크기: 40명 카드 @2x ≈ 40 × ~150KB, 테두리 10장 — 필요하면 @1x(목록)·@2x(상세)만.

## 시안
`docs/specs/render-art-crew-illust-draft.png`: 옥토(일반 테두리) · 팡(희귀 테두리) · 볼케(전설 테두리, 반짝) · 볼케(신화 테두리, 홀로 시안) + 지금 게임의 32px 도트 초상 비교.
카드 아래 칸(이름·계열·설명)은 비워 두었다 — 글자는 게임(UI)이 그린다.
