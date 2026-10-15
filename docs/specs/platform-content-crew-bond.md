# 기획: 선원 수집 강화 — 프로필·대사·이야기, 호감도, 전용 의상, 도감 단계 보상

- 상태: 초안 (2026-10-15, S5) · 개요 `platform-content-overview.md` (우선순위 3)
- 한 줄: 선원마다 성격(프로필·한 줄 대사·짧은 이야기 3편)이 있고, **함께 항해할수록**(출전 시간) 호감이 쌓여 이야기와 **전용 의상**이 열린다. 도감 칸을 채우면 단계 보상.
- 피로 규칙: 호감은 **출전만 해 두면 저절로**(오프라인 포함) 쌓인다. 선물은 선택(빠르게 하고 싶을 때만). 의상은 꾸미기 전용(능력치 없음) → 안 해도 손해 없음.

## 1. 규칙
1. **프로필**: 선원 상세 창에 이름·등급·가족(공격 종류)·한 줄 소개·한 줄 대사. 대사는 상세 창을 열 때와 승급 때 말풍선으로.
2. **호감도(bond)**: 점수 → 단계 1~5. 점수 출처
   - 출전 시간: 출전 중인 선원 각각 **분당 `bond.pointsPerDeployedMin`(1)점**. 오프라인 시간도 같은 규칙(상한 `meta.offline.maxSec`).
   - 선물: 선물 1개 = `gifts[].points`점, 그 선원의 **좋아하는 선물이면 ×`bond.favoriteMultiplier`(2)**.
3. **단계 문턱** `bond.levels`: `[0, 60, 240, 600, 1200]`점 (출전만으로 1시간 → 2단계, 4시간 → 3, 10시간 → 4, 20시간 → 5).
4. **열리는 것**: 2단계 이야기 1편 · 3단계 이야기 2편 · 4단계 이야기 3편 · **5단계 전용 의상**(있는 선원만, 1차 8명).
5. **의상**: 상세 창에서 입히기/벗기기. 초상·선원 슬롯·전장 그림이 바뀐다. 능력치 변화 없음.
6. **도감 단계 보상**: 도감 수 5·10·20·30·40에서 한 번씩 받기(기존 '5명마다 공격력 +3%'는 그대로 자동).
7. 선물 얻는 곳: 현상금 수요일 보상(`bounty`), 항해 일지 단계 보상(`voyage-log`), 보물상자 광고 대안 보상 중 하나. **팔지 않는다**(결제 없음).

## 2. 테이블 (economy, 글은 crew 레인 ARB)
### `crews.json` 선원마다 추가 키
```json
{"id": "octo", "…": "…", "favoriteGift": "fresh_fish", "lineKey": "crewOctoLine", "bioKey": "crewOctoBio",
 "storyKeys": ["crewOctoStory1", "crewOctoStory2", "crewOctoStory3"], "skin": "octo_captain"}
```
- `skin`은 1차 8명만(시작 선원 octo·turtle, 인기 선원 6 — 사용자/아트가 고름). 없으면 5단계 보상은 젬 `bond.noSkinGems`(100).
### `bond.json` (새 표)
```json
{"pointsPerDeployedMin": 1, "favoriteMultiplier": 2, "levels": [0, 60, 240, 600, 1200], "noSkinGems": 100,
 "gifts": [{"id": "fresh_fish", "points": 30, "nameKey": "giftFreshFish", "icon": "ui/gift_fish.png"},
           {"id": "shell_charm", "points": 30, "nameKey": "giftShellCharm", "icon": "ui/gift_shell.png"},
           {"id": "old_compass", "points": 60, "nameKey": "giftOldCompass", "icon": "ui/gift_compass.png"}],
 "skins": [{"id": "octo_captain", "crew": "octo", "portrait": "crews/skins/octo_captain.png", "sprite": "crews/skins/octo_captain_fleet.png"}]}
```
### `meta.json` `collection` 확장
```json
"collection": {"every": 5, "attackBonus": 0.03,
  "milestones": [{"count": 5, "gems": 50}, {"count": 10, "gems": 100}, {"count": 20, "summon": 1, "minRarity": "hero"},
                 {"count": 30, "gifts": {"old_compass": 5}}, {"count": 40, "summon": 1, "minRarity": "legend"}]}
```
- 술·담배 같은 선물은 쓰지 않는다(콘텐츠 등급, `docs/store/content-rating.md`).

## 3. 글 분량 (crew 레인 ARB `parts/crew.*.arb`, ko/en)
- 40명 × (소개 1 + 대사 1 + 이야기 3) = **200줄 × 2개 언어**. 이야기 1편 = 2~4문장(화면 한 장, 스크롤 없음).
- 톤: 설계서 4.10 선원 설정(성격·가족)에 맞춰, 짧고 웃기게. 무서운 묘사·폭력 묘사 없음.
- 1차 범위 제안: 40명 소개·대사 + 이야기는 **시작 선원·영웅 이상 16명**만, 나머지는 2차.

## 4. 세이브 (다음 버전)
- `CrewState`에 `bond: int`(점수, 기본 0), `skin: String?`(입은 의상, 기본 null).
- `GameState`에 `gifts: {giftId: 개수}`, `collectionClaimed: [5, 10]`(받은 도감 단계).
- 마이그레이션: bond 0, 의상 없음, 선물 0, 도감 단계는 받지 않은 상태(지금 도감 수로 받을 수 있게 된다 — 기존 플레이어에게 소급 보상).

## 5. 명령 · 이벤트
- `GiveGift(crewId, giftId, count)` — 보유 선원·선물 있음. 점수 반영, 단계 오르면 이벤트.
- `EquipSkin(crewId, skinId?)` — 5단계 + 의상 있음. null = 벗기.
- `ClaimCollectionMilestone(count)` — 도감 수 ≥ count, 아직 안 받음.
- 이벤트: `BondLevelUp(crewId, level)` · `StoryUnlocked(crewId, index)` · `SkinUnlocked(crewId, skinId)` · `CollectionMilestoneClaimed(count, reward)`.
- 출전 시간 점수는 엔진이 **분 단위로 모아** 반영(틱마다 쓰지 않음 — 세이브·이벤트 폭주 방지). 오프라인은 ClaimOffline 때 한 번에.

## 6. UI 화면 (ui)
1. **선원 상세 창**(선원 탭 카드 누르기 — 지금은 승급만): 위 = 큰 초상(의상 반영) + 이름·등급·별, 말풍선 대사 / 가운데 = 호감 막대(단계 하트 5칸, 다음 단계까지 '출전 3시간 · 선물 4개') / 아래 = 탭 3개 '정보 · 이야기 · 의상'.
   - 이야기: 3칸, 잠긴 칸은 '호감 3에서 열려요'. 읽은 칸은 표시.
   - 선물: 막대 옆 [선물] → 가진 선물 목록(좋아하는 선물에 하트 표시), 개수 선택.
   - 의상: 기본·전용 2칸, 입히기 버튼.
2. **도감 단계 보상**: 선원 탭 위 '도감 40/40' 줄에 다음 단계 보상 아이콘 + [받기].
3. 빨간 점(선원 탭 하나): 새 이야기 열림 · 의상 열림 · 도감 보상 받기 — 셋 중 하나라도. 선물이 있다는 이유만으로는 안 켬.
4. 승급·호감 단계업 때 선원 대사 말풍선 2초(팝업 아님).

## 7. 렌더 · 아트 (render/art)
- 의상 그림 1차 8명 × (초상 1 + 선원 슬롯·전장 그림 1) = **16장**, 기존 선원 그림 규격 그대로(도트 정수 배율).
- 선물 아이콘 3장(16px 격자, `design-quality-plan` ② 아이콘 규격).
- 렌더: 출전 선원의 `skin` 값으로 슬롯·전장 그림 고르기(없으면 기본). 단계업 반짝임(기존 승급 이펙트 작은 버전).
5. **태블릿(800×1280, dpr 2)**: 선원 상세 창을 좌우 2단(왼쪽 초상·호감, 오른쪽 탭 내용)으로 — 폰은 위아래. 선원 탭 격자는 6열(폰 4열).

## 8. 수용 기준
1. Given 선원 A 출전 When 60분(틱 또는 오프라인) Then A의 bond +60, 2단계, `BondLevelUp(A,2)`·`StoryUnlocked(A,1)` 1회씩.
2. Given 미출전 선원 When 시간 경과 Then bond 그대로.
3. Given A가 fresh_fish를 좋아함 When `GiveGift(A, fresh_fish, 1)` Then +60(30×2), 선물 −1. 선물 0이면 거절.
4. Given A 5단계·의상 있음 When `EquipSkin(A, octo_captain)` Then 슬롯·초상 그림이 의상, 전투 수치 동일(시나리오 리플레이 결과 그대로).
5. Given 의상 없는 선원 5단계 When 도달 Then 젬 +100, 의상 칸 없음.
6. Given 도감 12 When `ClaimCollectionMilestone(10)` Then 젬 +100, 같은 명령 다시 → 거절. `ClaimCollectionMilestone(20)` → 거절.
7. Given v5 세이브 When 불러오기 Then bond 0·선물 0, 도감 단계 소급 받기 가능.
8. 골든: 선원 상세 창 3탭 ko/en, 384·360dp 넘침 없음(긴 영어 이름 포함).

## 9. 레인 분담
| 레인 | 할 일 |
| --- | --- |
| economy | `bond.json`, `crews.json` 키, `collection.milestones`, 점수 집계(분 단위·오프라인), 명령 3개, 마이그레이션 |
| crew 글(ARB 소유 레인) | 소개·대사 40명, 이야기 1차 16명 × 3편 (ko/en) |
| ui | 선원 상세 창 3탭, 선물 시트, 도감 단계 줄, 말풍선, 빨간 점 |
| render/art | 의상 16장, 선물 아이콘 3장, 의상 그림 선택, 단계업 연출 |
| S1 | 계약·세이브 버전, 리뷰 |
