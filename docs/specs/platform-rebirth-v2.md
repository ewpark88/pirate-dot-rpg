# 스펙: 환생 v2 — 보물지도 상점 · 명예 외형 · 환생 상자 · 횟수별 해금

- 상태: 초안 (2026-10-15, S5 작성 — S1 검토 대기) · 기획 레인: platform · 구현: economy·battle·render·ui·S1(계약) · 설계서 절: 4.5 · 4.8 · 7.2
- 바탕: `economy-rebirth.md`(승인, 환생 1·3 결정 포함)와 `ui-rebirth-boss.md`(승인). 둘 다 그대로 두고 **덧붙인다**.
- 출발점: 사용자 — "환생하면 대포·선체·돛이 초기화되고 외형도 다시 허접해지는데 뭐가 좋냐, 메리트가 없다."
  지금 환생해서 얻는 것은 '조각당 피해·골드 +5%' 숫자 하나뿐이다. 그런데 잃는 것(배 레벨·외형·배 등급 그림)은 눈에 바로 보인다.
- 결정 4가지(사용자, S1 경유): ① 보물지도 상점(영구 강화 트리) ② 명예 외형 유지 + 환생 1·3·5·10회 전용 스킨
  ③ 환생 즉시 보상 상자 + 버튼 미리보기(전투력 ×N · 약 M분이면 지금 위치 돌파) ④ 횟수별 새 콘텐츠(보물 바다 해역·선원 최대 레벨).

## 목적 (설계서 1장 4가지 검사)
- **시원한가**: 환생 직후 상자를 열고, 상점에서 지도 조각을 쓰고, 배를 다시 보면 **예전 모습 그대로**다.
  첫 환생 뒤 **30분 안에** 이전 최고 스테이지를 넘는다. 빠른 항해(f0)로 초반이 순식간에 지나간다.
- **단순한가**: 상점은 3줄(줄마다 2~3칸)이고 칸마다 '다음 레벨 효과 · 비용' 하나만 보인다. 미리보기는 한 줄('전투력 ×2.1 · 약 12분이면 스테이지 58 돌파').
- **피로가 없는가**: 기한 있는 보상이 없다. 상자는 받기 버튼 없이 바로 지갑으로 간다. 상점 빨간 점은 '살 수 있는 칸이 있을 때 항해 탭에 1개'뿐이다.
  해금은 영구다. 보물 바다는 일일 제한이 없는 선택 콘텐츠다.
- **공정한가**: 모든 수치는 테이블(`rebirth.json`, `meta.rebirth`)에 있다. 미리보기 숫자는 실제 계산 함수와 같은 것을 쓰고, 오차는 sim으로 잰다(수용 기준 13).
  환생은 결제와 무관하다.

## 0. 지도 조각 — '쓰는 조각'과 '모은 조각' 분리 (계약 변경, S1)
상점에서 조각을 쓰면 지금 규칙(보너스 = 보유 조각 × 5%)에서는 **보너스가 줄어든다**. 그러면 '사면 약해지는' 상점이 된다.
- `wallet.mapPieces` = **쓸 수 있는 조각**(상점 화폐).
- `progress.mapPiecesEarned` (새 필드) = **모은 조각 누계**. 줄지 않는다.
- `rebirthBonus = mapPiecesEarned × bonusPerPiece`. 근거를 '보유'에서 '누계'로 바꾸므로, 상점 구매는 순수한 이득이다.
- 환생 때는 두 값에 같은 양을 더한다. 운영자 지급(`OpGrantPieces`)도 둘 다 늘린다.

## 1. 보물지도 상점 (영구 강화 트리) — economy(효과 계산)·battle(전투 적용)·ui(화면)
- 테이블: 새 파일 `packages/game_data/tables/rebirth.json` `shop`. 항목마다 `{id, row, effect, perLevel, maxLevel, costBase, costGrowth, nameKey, descKey}`.
- **비용** `cost(level) = ceil(costBase × costGrowth^level)`. level은 지금 레벨이고 0부터 센다.
- **줄 해금**(트리): 1줄은 처음부터 열려 있다. 2줄은 **상점에 쓴 조각 누계** ≥ 30, 3줄은 ≥ 150이면 열린다. 첫 환생의 조각(스테이지 45~55 → 25~66개)은 1줄에 거의 다 들어간다.
- 효과는 **환생해도 유지**된다(영구). 상점 레벨은 `OpReset`으로만 지워진다.

| 줄 | id | 이름(ko) | 효과(레벨당) | 상한 | 비용 base×growth | 1레벨~상한 비용 | 적용 레인 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `startParts` | 순풍 출항 | 환생·새 회차 시작 때 대포·선체·화물 **시작 레벨 +5**, 돛·망루 +1 | 10 | 3 × 1.35 | 3,5,6,8,10,14,19,25,34,45 (합 169) | economy |
| 1 | `discount` | 상인 단골 | 배 강화 골드 비용 −4% | 10 | 4 × 1.4 | 4,6,8,11,16,22,31,43,60,83 (합 284) — 최대 −40% | economy |
| 1 | `bossTime` | 모래시계 | 보스 제한 시간 +3초(30 → 최대 45) | 5 | 6 × 1.5 | 6,9,14,21,31 (합 81) | battle |
| 2 | `offline` | 긴 정박 | 오프라인 최대 시간 +1시간(8 → 최대 12) | 4 | 10 × 1.8 | 10,18,33,59 (합 120) | economy·platform |
| 2 | `critChance` | 매의 눈 | 치명타 확률 +1%p(배 상한 `critChanceMax` 0.5는 그대로) | 10 | 5 × 1.4 | 5~104 (합 352) | battle |
| 2 | `critDamage` | 급소 사격 | 치명타 배수 +0.1(2.0 → 최대 3.0) | 10 | 5 × 1.4 | 5~104 (합 352) | battle |
| 3 | `fleetSlot` | 넓은 갑판 | **출전 칸 +1**(배 등급 칸 수 + 레벨) | 2 | 60 × 4 | 60, 240 (합 300) | battle·ui |
| 3 | `pieceGain` | 보물 감각 | 환생 때 얻는 조각 +10% | 10 | 8 × 1.5 | 8~308 (합 910) | economy |
| 3 | `fastSail` | 지름길 | 빠른 항해 범위 `rebirthSkip.fraction` +0.05(0.3 → 최대 0.5) | 4 | 12 × 1.6 | 12,20,31,50 (합 113) | battle |

- 왜 이 순서인가: 첫 환생 직후 체감이 큰 것을 1줄에 둔다. **시작 레벨**은 바로 강하게 출발하게 하고, **할인**은 같은 골드로 더 많이 올리게 하며, **보스 시간**은 막힌 벽을 넘게 한다.
  출전 칸은 체감이 가장 크지만 3줄에 둔다(첫 환생부터 주면 초반 균형이 깨진다 — sim 확인 항목).
- 전부 채우는 데 조각 약 2,800개가 든다. 스테이지 100(345개)~150(767개) 환생을 6~10번 하는 양이다.
- `startParts`: 환생 처리에서 배 부위 레벨을 0이 아니라 `startLevel(part)`로 둔다. 골드는 0 그대로다.
  레벨이 오르며 외형 단계를 넘어도 `ShipLookChanged`는 내지 않는다(명예 외형이 이미 그 모습이므로).
- `offline`: 코어 `offline.maxSec`를 쓰는 모든 곳(오프라인 보상, 상자 추정, **platform `OfflineFullNotifier.fullAfter`**)은 실효값 함수 `offlineMaxSec(state, tables)`를 쓴다.
  platform 몫: main.dart의 `fullAfter`를 상태에서 읽게 바꾼다.
- `fleetSlot`: 칸 수 = `tier.slots + level`, 상한 7. 편성 UI는 칸 수를 상태에서 읽는다(지금은 테이블 tier).
- 미리보기(UI용) `RebirthShopView shopView(state, tables)`: 항목마다 `{id, level, maxLevel, cost?, unlocked, affordable, effectNow, effectNext}`와 `spentTotal`, `nextRowAt`.
  표시용 숫자 계산을 UI에서 하지 않게 한다.

## 2. 명예 외형 + 환생 스킨 — economy(기록)·render(그림)·ui(고르기)
### 2-1. 명예 외형 (능력치만 초기화, 외형은 유지)
- 새 필드 `ship.honor`: 부위 id → **지금까지 도달한 최고 외형 단계**(ship_parts.json `visualStages`의 인덱스)와 `honorTier`(도달한 최고 배 등급 인덱스).
  강화로 단계가 오를 때 갱신하고, 환생 때는 지우지 않는다.
- 렌더가 그리는 단계는 부위마다 `max(지금 레벨의 단계, honor 단계)`, 배 등급 그림(`ship_t1~t4`)은 `max(지금 등급, honorTier)`이다.
  **능력치(칸 수·피해 보너스)는 지금 등급 그대로**다. 그림만 명예를 따른다.
- `ShipLookChanged`는 honor를 **넘어설 때만** 낸다. 환생 뒤 다시 같은 단계에 도달해도 축하 연출을 반복하지 않는다(피로).
  ShipTierUp도 같다: 연출은 honorTier를 넘을 때만 하고, 능력치 변화는 그대로 적용한다.
- 강화 화면의 부위 칸: 외형은 명예 단계로 보인다. 레벨 숫자는 지금 레벨이다. 칸 아래 작은 글씨로 '명예 외형'을 표시한다(`uiRebirthHonorLook`).

### 2-2. 환생 전용 선박 스킨
- 테이블 `rebirth.json` `skins`: `{id, rebirths, hull, sail, flag, nameKey}`. hull·sail·flag는 팔레트 바꾸기 값이다(색 4~6개). 그림을 새로 그리지 않고 **기존 배 부품 위에 색만 바꾼다**(무료, 코드 그림).

| 환생 | id | 이름(ko) | 도색 | 돛 | 깃발 |
| --- | --- | --- | --- | --- | --- |
| 1 | `coral` | 산호 항해단 | 산호 분홍 선체 | 흰 돛 + 분홍 줄 | 조개 문양 |
| 3 | `storm` | 폭풍 사냥꾼 | 짙은 남색 | 회색 돛 + 번개 줄 | 번개 |
| 5 | `gold` | 황금 함대 | 금박 테두리 | 크림색 돛 + 금 테 | 왕관 해골 |
| 10 | `phantom` | 유령선 | 반투명 청록 + 은은한 빛 | 찢어진 돛 | 유령 해골 |

- 새 필드 `ship.skin`(String?, 기본 null = 기본 배)과 `ship.skinsOwned`(Set<String>). 환생 횟수가 `rebirths`에 닿으면 자동으로 얻는다(`SkinUnlocked`).
  처음 얻은 스킨은 자동으로 장착한다. 사용자가 고른 적이 있으면 바꾸지 않는다.
- 명령 `SelectShipSkin(skinId | null)`. 갖지 않은 스킨이면 무시한다.
- render 몫: `ship_parts_painter` 팔레트 바꾸기 + `phantom`의 은은한 빛(알파 펄스, 전장 성능 예산 안). 전장·강화 화면·환생 상자 연출에서 같은 그림을 쓴다.
  품질 기준은 battle_ship.gif 이상이다.

## 3. 환생 즉시 보상 상자 + 버튼 미리보기 — economy·ui·render
### 3-1. 상자 (누르면 바로 지급, '받기' 버튼 없음)
- `rebirth.json` `chest`:
  - 젬 `gems = min(gemsMax, gemsBase + gemsPerRebirth × (rebirths − 1))`: 50 + 10×(n−1), 최대 150. n은 이번 환생 뒤의 횟수다.
  - 소환 `summons`: 1회. 5회차부터 2회, 10회차부터 3회. 모두 **영웅 이상 보장**(출석 7일차 보상과 같은 즉시 소환 경로, `minRarity: hero`).
    결과는 기존 소환 결과 화면으로 보인다(`lastSummon`).
  - 칭호: 환생 1·3·5·10·20회에 칭호 하나(아래 표). 스킨과 같은 회차이고, 20회만 칭호뿐이다.
- 첫 환생은 환생 버튼 + 상자를 합해 지금보다 **젬 50 + 영웅 이상 1명 + 스킨 + 칭호**를 더 준다. 사용자가 말한 '메리트'를 손에 쥐어 주는 몫이다.
- 이벤트: 기존 `RebirthDone`에 `gems`, `summons`, `title?`, `skin?`를 더한다(계약 변경, S1). UI는 이것 하나로 상자 팝업을 연다.
  상자 팝업은 '열기' 한 번 누르면 내용이 한꺼번에 펼쳐지는 연출이다. 지급은 이미 끝난 뒤이므로 닫아도 잃는 것이 없다.

| 환생 | 칭호 id | ko | en |
| --- | --- | --- | --- |
| 1 | `deckhand` | 지도를 펼친 자 | Map Reader |
| 3 | `navigator` | 노련한 항해사 | Seasoned Navigator |
| 5 | `captain` | 바다의 선장 | Sea Captain |
| 10 | `admiral` | 전설의 제독 | Legendary Admiral |
| 20 | `seaKing` | 일곱 바다의 왕 | King of Seven Seas |

- 새 필드 `progress.titles`(List<String>)와 `settings.title`(String?, 고른 칭호). 명령 `SelectTitle(id | null)`.
  칭호는 항해 탭 위 해역 이름 옆에 작은 띠로 보인다(UI). 능력치는 없다.

### 3-2. 환생 버튼 미리보기 — '전투력 ×N · 약 M분이면 지금 위치 돌파'
- 코어 함수 `RebirthForecast rebirthForecast(state, tables)`(economy): `{powerMultiplier, minutesToBeat, targetStage}`.
  - `targetStage` = 지금 회차 스테이지(`progress.stage`).
  - `powerMultiplier` = 환생 직후 **스테이지 1 시작 상태의 전투력 추정**(상점 효과 포함, 보너스는 누계 + gain) ÷ **환생 전 같은 시작 상태의 추정**.
    '같은 시작 조건에서 얼마나 강해지나'를 뜻하고, 지금 장비와 비교하는 값이 아니다.
    표시는 소수 1자리이고 1.1 미만이면 '×1.1 미만'으로 보인다.
  - `minutesToBeat`: 해석적 추정. 스테이지 1부터 `targetStage`까지, 스테이지마다 `max(바닥 시간, 적 체력 합 ÷ 추정 DPS)`를 더한다.
    바닥 시간은 빠른 항해 구간이면 보스만, 아니면 파 3개 + 보스 + 이동이다. DPS는 그 시점까지 번 골드를 기존 자동 강화 정책으로 쓴 배 레벨에서 구한다.
    sim을 돌리지 않는다(버튼 화면에서 1ms 안). 결과는 5분 단위로 올림하고, 60분을 넘으면 '1시간+'로 보인다.
  - 잠겨 있으면(스테이지 < 40) 계산하지 않는다(null).
- UI: 환생 카드에 한 줄을 넣는다(`uiRebirthForecast`: '전투력 ×{mult} · 약 {min}분이면 스테이지 {stage} 돌파').
  확인 창에는 '그대로' 줄에 '배 외형(명예)'를 추가하고, '얻는 것' 줄에 상자 내용(젬·소환·스킨/칭호)을 추가한다.

## 4. 환생 횟수별 새 콘텐츠 해금 — economy·battle·render·ui
- `rebirth.json` `unlocks`: `[{rebirths, kind, value}]`. 해금 여부는 `rebirths`로 계산하고, 세이브 필드는 두지 않는다.

| 환생 | 해금 | 내용 |
| --- | --- | --- |
| 1 | 상점 1줄 | (상점 자체) |
| 2 | 선원 최대 레벨 75 → **80** | 신화 구간 연장(rarities mythic levelMax와 growth.maxLevel을 실효값 함수로) |
| 3 | **보물 바다** 1해역 | 아래 4-1 |
| 5 | 선원 최대 레벨 **85** + 보물 바다 2해역 | |
| 8 | 보물 바다 3해역 | |
| 10 | 선원 최대 레벨 **90** | |

- 최대 레벨 실효값 `crewMaxLevel(state, tables)`. 76~90 레벨의 경험치·승급 규칙은 신화 구간(expToNext.mythic 30, powerPerLevel 0.08)을 그대로 잇는다. 새 등급은 없다.
  `CrewPromoted` 없이 레벨만 오른다. 상한이 오르면 `ContentUnlocked(kind: 'crewMaxLevel', value: 80)`를 낸다 → UI 토스트 1번.

### 4-1. 보물 바다 (고난도 해역) — 결정 필요 ①
- **추천안 A(가벼움, battle 몫 작음)**: '보물 바다 항로'를 켜고 환생하면 **다음 회차 전체**가 보물 바다가 된다.
  적 체력 ×`hpMultiplier`(1해역 2.0, 2해역 3.5, 3해역 6.0), 골드 ×1.5, 그 회차 환생 조각 ×(1.5 / 2.0 / 3.0).
  배경은 지금 해역 그림에 **금빛 물결 팔레트**를 덮어 쓴다(render — 새 그림 없음, 코드 오버레이). 처음 깬 보물 바다 보스마다 1회 보상(젬 30·조각 5)을 준다. 일일 제한은 없다.
  - 상태: `progress.treasureSea`(int?, 이번 회차 해역 번호). 명령 `SetTreasureRoute(int? sea)`는 환생 확인 창의 토글이고 다음 환생에 적용된다.
  - 이유: 새 진행 축 없이 '어려운 대신 조각을 더 주는 회차'라서 기존 전투·sim을 그대로 쓴다. 반복 회차에 변화를 준다.
- 대안 B(무거움): 본 항해와 별개인 보물 바다 스테이지 트랙(`treasureStage`)을 두고, 항해 탭 버튼으로 오간다. 전투 상태 전환·별도 sim이 필요해서 battle 일이 크다.
- S1·사용자가 고른다. 아래 수용 기준은 A로 쓴다.

## 5. 세이브 v6 (S1 — 계약·마이그레이션)
| 필드 | 위치 | 기본 | v5 → v6 마이그레이션 |
| --- | --- | --- | --- |
| `mapPiecesEarned` | progress | 0 | = `wallet.mapPieces`(지금 보유 = 지금까지 모은 양, 쓴 적이 없으므로) |
| `rebirthShop` | 최상위 `Map<String,int>` | {} | {} |
| `honor` | ship `{parts: Map<String,int>, tier: int}` | 단계 0 / 0 | parts = 지금 레벨의 단계, **tier = `bestStage`의 배 등급**(이미 환생한 사람도 최고 등급 그림을 돌려받는다) |
| `skin`, `skinsOwned` | ship | null, [] | `rebirths` ≥ 1·3·5·10인 스킨을 지급하고 첫 것을 장착 |
| `titles` | progress | [] | `rebirths` 기준으로 지급 |
| `title` | settings | null | null |
| `treasureSea` | progress | null | null |

- 이미 환생한 사람에게는 상자를 소급해서 주지 않는다(젬·소환 소급은 균형을 깬다). 스킨·칭호·명예 등급만 준다.
  첫 실행 때 팝업은 띄우지 않는다. 항해 탭 상점 빨간 점 1개만 둔다.
- `schemaVersion` 5 → 6, `migrateV5ToV6`. 테스트: v5 픽스처(환생 0회, 3회) 두 개.

## 6. 명령 · 이벤트 (계약 변경 목록 — S1)
- 명령(사용자): `BuyRebirthUpgrade(id)` · `SelectShipSkin(id?)` · `SelectTitle(id?)` · `SetTreasureRoute(sea?)`.
- 명령(운영자): `OpGrantPieces(n)`(쓸 조각·누계 둘 다) · `OpSetRebirths(n)`(해금·스킨·칭호 확인용, 상자는 안 줌).
- 이벤트:
  - `RebirthUpgradeBought(id, level)`
  - `RebirthDone` += `gems, summons, title?, skin?`
  - `SkinUnlocked(id)`
  - `ContentUnlocked(kind, value)`: kind는 `crewMaxLevel` | `treasureSea` | `shopRow`
  - `SaveRequested('rebirthShop')`: 구매 때
- 거부: 조각 부족, 상한, 잠긴 줄의 구매는 상태를 그대로 두고 이벤트를 내지 않는다(UI는 버튼을 미리 끈다).

## 7. 화면 (ui 몫) — 문구는 `parts/ui.*.arb`
1. **항해 탭 환생 카드**: 기존 카드에 미리보기 한 줄을 더하고, '보물지도 상점' 버튼을 붙인다(살 수 있으면 빨간 점).
2. **환생 확인 창**: 잃는 것 / 그대로(+배 외형) / 얻는 것(+상자). 보물 바다 해금 뒤에는 항로 토글이 있다(해역 고르기, 체력·조각 배수 표시).
3. **환생 상자 팝업**: 상자 열림 → 젬·소환·스킨·칭호가 순서대로 → 소환은 기존 결과 화면으로 넘긴다 → '항해 시작'.
   스킨을 얻었으면 새 배를 크게 보여 준다(render 그림 재사용).
4. **보물지도 상점 화면**: 3줄 트리(잠긴 줄은 '조각 N개를 쓰면 열림' 막대). 칸을 누르면 아래 시트에 '레벨 a → a+1 · 효과 x → y · 비용 c' + 구매 버튼.
5. **배 스킨 고르기**: 강화 화면 배 그림을 길게 누르거나 작은 '스킨' 버튼 → 가로 목록(잠긴 것은 '환생 N회'로 표시).
6. **칭호**: 항해 탭 위 띠를 누르면 칭호 목록이 열린다.
- 태블릿·작은 폰(360/384/411, 800×1280)에서 레이아웃이 유연해야 한다. 골든: 상점(ko/en), 상자 팝업, 확인 창(보물 바다 토글 포함).

## 8. 렌더 몫
- 명예 외형: 부위 단계 입력을 `max(지금, honor)`로 바꾼다(그리기 코드 변경 최소).
- 스킨 4종 팔레트 바꾸기와 phantom 빛.
- 보물 바다 금빛 물결 오버레이(전장 배경 위, 성능 예산 안).
- 상자 열림 연출: 뚜껑, 빛줄기, 아이템이 튀어나옴. 기존 상자 그림이 있으면 재사용한다.

## 수용 기준 (Given / When / Then) — 하나마다 테스트, 13·14는 sim
1. Given 조각 10(누계 10) When `BuyRebirthUpgrade(startParts)` Then 쓸 조각 7, 누계 10, `rebirthBonus` 그대로 0.5, 상점 레벨 1, `RebirthUpgradeBought`.
2. Given 조각 2 When `startParts` 구매 Then 변화 없음, 이벤트 없음. Given 2줄 잠김(쓴 누계 29) When `offline` 구매 Then 변화 없음.
3. Given `startParts` 2, 스테이지 50 When `Rebirth` Then 대포·선체·화물 레벨 10, 돛·망루 2, 골드 0, `ShipLookChanged` 없음.
4. Given `discount` 5 Then 대포 레벨 0→1 비용 = 원래 × 0.8(내림 규칙은 기존 비용 함수와 같음).
5. Given `bossTime` 3 Then 보스 제한 시간 39초. Given `critChance` 10 + 망루 최대 Then 치명 확률 ≤ 0.5.
6. Given `offline` 2 Then `offlineMaxSec` = 36000, 오프라인 보상과 `OfflineFullNotifier.fullAfter`가 같은 값을 쓴다.
7. Given 배 등급 sloop(칸 4) + `fleetSlot` 1 Then 출전 칸 5, `SetFleetSlot(4, …)` 허용.
8. Given 대포 레벨 60(단계 4), 스테이지 85(warship) When `Rebirth` Then 능력치는 레벨 0·dinghy, 렌더 입력 단계는 대포 4, 배 그림은 warship.
   When 대포를 다시 레벨 35로 올림 Then `ShipLookChanged` 없음. 레벨 90 Then `ShipLookChanged(cannon, 5)`.
9. Given 환생 0회 When `Rebirth`(스테이지 50) Then 젬 +50, 영웅 이상 소환 1, 칭호 `deckhand`, 스킨 `coral` 보유·장착, `RebirthDone(gems: 50, summons: 1, title: deckhand, skin: coral)`.
   Given 환생 4회 When `Rebirth` Then 젬 90, 소환 2, 스킨 `gold`. 사용자가 고른 스킨이 있으면 바뀌지 않는다.
10. Given 환생 2회 Then `crewMaxLevel` 80, 레벨 75 선원이 경험치로 76이 된다. 환생 1회 Then 75에서 멈춘다.
11. Given 환생 3회, `SetTreasureRoute(1)` When `Rebirth`(스테이지 60) Then 다음 회차 `treasureSea` 1, 적 체력 ×2.0, 그 회차 환생 조각 ×1.5.
    `SetTreasureRoute(2)`는 환생 3회에서 무시된다.
12. 세이브 v5 픽스처(환생 3회, mapPieces 120, bestStage 90) → v6: 누계 120, 보유 120, honor.tier = warship, 스킨 coral·storm 보유(storm 장착 아님 — 첫 것 coral), 칭호 2개.
13. `rebirthForecast`: 스테이지 50, 조각 0, 상점 0 Then powerMultiplier > 1. minutesToBeat가 sim(같은 상태에서 실제 환생 후 이전 최고 돌파 시간)의 ±30% 안이다(스테이지 45·60·90 세 점).
14. **sim 목표**(`meta.sim.targets`에 추가):
    - `rebirthBeatBestMin` {min 8, max 30}, schedule continuous: 첫 환생 뒤, 그 회차에서 사기로 한 상점 정책(1줄 싼 것부터)으로 이전 최고 스테이지를 넘는 시간. 너무 빨라도(8분 미만) 실패다(환생이 공짜가 되지 않게).
    - 기존 `rebirthRecoverSec` ≤ 300과 `wallMaxMin` ≤ 20 유지. `firstMythicDays` 28~56은 상점 + 최대 레벨 연장 뒤에도 유지(벗어나면 economy가 숫자 조정).
    - 60일 일정에서 상점 전체 구매율 리포트(참고): 30일에 40~60%면 적당하다.
15. 운영자: `OpGrantPieces(500)` → 상점 3줄 모두 살 수 있음. `OpSetRebirths(10)` → 스킨 4종 보유, 최대 레벨 90, 보물 바다 3해역 선택 가능. 상자는 지급하지 않는다.

## 문구 (ko / en) — 키 (ui 레인 ARB, 스킨·칭호·상점 이름은 economy 테이블 nameKey → ui ARB)
| 키 | ko | en |
| --- | --- | --- |
| `uiRebirthShop` | 보물지도 상점 | Treasure Map Shop |
| `uiRebirthForecast` | 전투력 ×{mult} · 약 {min}분이면 스테이지 {stage} 돌파 | Power ×{mult} · about {min} min to pass stage {stage} |
| `uiRebirthHonorLook` | 명예 외형 | Honor look |
| `uiRebirthKeepLook` | 그대로: 선원·도감·젬·배 외형 | Kept: crew, collection, gems, ship look |
| `uiRebirthChest` | 환생 보물 상자 | Rebirth Treasure Chest |
| `uiRebirthChestOpen` | 열기 | Open |
| `uiRebirthSail` | 항해 시작 | Set Sail |
| `uiRebirthRowLocked` | 조각 {count}개를 더 쓰면 열려요 | Spend {count} more pieces to unlock |
| `uiRebirthTreasureRoute` | 보물 바다 항로 | Treasure Sea Route |
| `uiRebirthTreasureInfo` | 적 체력 ×{hp} · 조각 ×{pieces} | Enemy HP ×{hp} · Pieces ×{pieces} |
| `uiCrewMaxLevelUp` | 선원 최대 레벨 {level}! | Crew max level {level}! |
| `uiShipSkin` | 배 스킨 | Ship Skin |
| `uiSkinLocked` | 환생 {count}회 | Rebirth ×{count} |
| `rebirthShop*Name`·`*Desc` 9쌍, `shipSkin*` 4, `title*` 5 | 위 표 | 위 표 |

## 운영자 모드에서 불러보는 법
`OpJumpStage(60)` → 항해 탭 미리보기 → `Rebirth` → 상자 팝업 → 상점에서 구매 → 강화 화면(명예 외형).
해금·스킨 확인은 `OpSetRebirths(10)` + `OpGrantPieces(3000)`.

## 일 나누기 (제안 — S1이 배정)
| 순서 | 레인 | 일 | 의존 |
| --- | --- | --- | --- |
| 0 | S1 | 계약: 세이브 v6 필드·마이그레이션, 명령 6개·이벤트 4개, `rebirth.json` 스키마(game_data) | — |
| 1 | economy | 조각 분리, 상점(구매·효과 함수·shopView), 시작 레벨·할인·오프라인·조각 배수, 상자, 명예 기록, 스킨·칭호 지급, 최대 레벨, forecast, sim 목표 | 0 |
| 2 | battle | 보스 시간·치명 2종·출전 칸·지름길, 보물 바다 배수(안 A) | 0 |
| 3 | render | 명예 외형 입력, 스킨 4종, phantom 빛, 금빛 물결, 상자 연출 | 0 (그림은 1과 병행) |
| 4 | ui | 카드 미리보기·확인 창·상자 팝업·상점·스킨·칭호 + 골든 | 1 |
| 5 | platform | `fullAfter` 실효값 연결, 기기 QA(환생 1회 흐름 30분 실측) | 1 |

## 결정 필요 (사람)
- ① 보물 바다: **추천 A(다음 회차 전체를 고난도로, 조각 배수)** vs B(별도 스테이지 트랙).
- ② 조각 보너스 근거를 '누계'로 바꾸는 것(0절) — 추천 그대로. 아니면 상점 화폐를 따로 둬야 한다(새 화폐 = 더 복잡).
- ③ 이미 환생한 사람의 소급: **스킨·칭호·명예 등급만**(추천) vs 상자까지.
- ④ 출전 칸 +1을 3줄(조각 150 이상 쓴 뒤)에 두는 것 — sim에서 초반 균형이 괜찮으면 2줄로 당겨도 된다.
