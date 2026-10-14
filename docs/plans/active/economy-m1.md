# economy: M1 EconomySystem + game_cli sim

- 레인: economy (S2) · 브랜치 `lane/economy` · 시작 2026-10-14
- 스펙 상태: **승인됨 (2026-10-14, 사용자)**. `docs/specs/`는 shared 경로라 여기에 둔다 — S1이 원하면 `docs/specs/economy-m1.md`로 옮긴다.
- 설계서: 4.2 · 4.3.1 · 4.3.3 · 4.7 · 4.8(상한) · 7.2 · 9.3

## 스펙 초안

### 목적
- 시원한가: 25레벨 도약(×2), 높은 등급 카드 즉시 점프, 소환 대박.
- 단순한가: 버튼은 강화·소환·일괄 합치기·승급뿐. 숫자는 전부 테이블에서.
- 피로가 없는가: 오프라인 8시간 상한까지 자동 적립, 일괄 합치기 한 번.
- 공정한가: 확률은 `rarities.json` 그대로 공개, 50회 천장, 신화는 승급으로만.

### 규칙
1. **배 부위 강화** `UpgradePart(part, times)`
   - 비용 `costBase × costGrowth^Lv` (Lv = 현재 레벨). `times`번 반복, 골드가 모자라면 살 수 있는 만큼만.
   - `maxLevel`에 닿으면 더 사지 않는다. 한 번도 못 사면 상태 그대로(null 아님) + 이벤트 없음.
   - 레벨이 `milestoneEvery`의 배수가 되면 `PartMilestone`. 매번 `PartUpgraded`, 끝에 `SaveRequested`.
2. **효과 공식** (전투가 쓰는 순수 함수, `economy/ship_stats.dart`)
   - `exp`: `base × growth^Lv`, `linear`: `base + growth × Lv`, 둘 다 `× milestoneMultiplier^floor(Lv / milestoneEvery)`.
   - 돛 공격 속도는 `caps.attackSpeedMax`, 망루 치명타는 `caps.critChanceMax`로 자른다.
   - 선원 파워 배율 `(1 + powerPerLevel × (Lv − 1)) × promotionMultiplier^(등급 순번)`. 등급 = 레벨 구간(`rarities.json`).
3. **소환** `Summon(count)` — 1회 또는 10연, `summonCostGems × count` 젬. 모자라면 무시.
   - 등급 확률 `rarities.json summonRate`(설계서 65/27/7/1로 수정), 선원은 40명 균등.
   - 천장: `pityCount`가 `pity.count − 1`이면 다음 소환은 `pity.minRarity` 이상 확정(그 이상 등급끼리 확률 비례). 영웅 이상이 나오면 0으로.
   - 처음 보는 선원 → 그 등급 첫 레벨로 보유 + 도감 등록. 이벤트 `CrewSummoned`.
4. **카드 받기** (소환·보스·오프라인 공통 `receiveCard`) — 결정 ①: 경험치 적립 + `cards` 1장
   - 받은 카드 등급이 선원 현재 등급보다 높으면 즉시 그 등급 첫 레벨로 점프(경험치 0).
   - 신화 Lv75 선원의 카드는 증표 `tokenPerSurplusCard`개.
5. **일괄 합치기** `MergeAllCards` — 모든 선원의 카드를 경험치로 바꿔 레벨업. 등급 마지막 레벨(승급 문)에서 멈춘다.
   - 레벨 1 올리는 경험치는 등급별 표(설계서 4.3.3: 1·3·6·20·30) — `growth.json expToNext`를 등급별 값으로 바꾼다.
6. **승급** `PromoteCrew(id)` — 등급 마지막 레벨 + 카드 N장 + 골드(+증표). 다음 등급 첫 레벨로.
   - 승급 골드 = 현재 스테이지 일반 몬스터 처치 골드(`waves.json monster`) × 배수(100·300·1,000·3,000). 결정 ③
7. **보스 카드** `grantBossCards(state, ctx)` — 결정 ②, 전투가 호출. 스테이지 1~10은 2장, 이후 `1 + floor(stage / 150)`장, 출전 선원 중 무작위(처음 10번은 옥토), 카드 등급 80/17/2.8/0.2%.
8. **오프라인 보상** `ClaimOffline` — `초당 골드 추정 × min(now − savedAt, offline.maxSec)`. 역행이면 0. 카드 `cardsPerMax`장 비례(내림), 출전 선원에게.
   - 초당 골드 추정 = `한 파 골드 / (한 파 HP ÷ 원정대 DPS + 이동 시간)` — DPS 추정은 `ship_stats` 함수로.
9. **game_cli sim** — 가상 플레이어(가장 싼 강화, 젬 쌓이면 소환, 보스 실패 시 60초 파밍 후 재도전).
   전투 엔진이 머지되기 전에는 DPS·보스 판정을 추정식으로. `--smoke`(1명 × 2시간)는 30초 안, 7.2 지표 표를 출력하고 목표를 벗어나면 경고.

### 수용 기준 (Given / When / Then)
1. Given 골드 충분, 대포 Lv0 When `UpgradePart(cannon, times: 3)` Then Lv3, 골드는 `10×(1+1.15+1.15²)` 감소, `PartUpgraded` 3개.
2. Given 대포 Lv24 When 강화 1회 Then `PartMilestone`, 공격력 = `4×1.11^25×2`.
3. Given 골드 부족 When 강화 Then 상태·이벤트 변화 없음.
4. Given 돛 Lv30(최대) When 강화 Then 변화 없음 · 망루 Lv45의 치명타 = 0.5.
5. Given 젬 = 30×10 When `Summon(count:10)` Then 카드 10장, 젬 0, `CrewSummoned` 10개.
6. Given pityCount 49 When 소환 1회 Then 영웅 이상, pityCount 0.
7. 100만 회 소환 시뮬의 등급 비율이 표시 확률(천장 제외 분포) ±0.2%p (설계서 9.3).
8. Given 일반 Lv5 선원, 전설 카드 When 받기 Then Lv46.
9. Given 일반 Lv1 + 적립 경험치 충분 When `MergeAllCards` Then Lv15에서 멈추고 남는 경험치·카드 장수는 보존.
10. Given Lv15 + 카드 3장 + 골드 When `PromoteCrew` Then Lv16, 카드·골드 차감, 파워 ×1.35.
11. Given 신화 Lv75, 카드 1장 When 받기 Then 증표 +1, 카드 그대로 0.
12. Given savedAt 10시간 전 When `ClaimOffline` Then 8시간분 골드·카드 3장 · Given savedAt 미래 Then 0.
13. `game_cli sim --smoke --hours 2`가 30초 안에 끝나고 7.2 표를 출력(종료 코드 0).

### 문구 (ko / en)
M1은 코어·CLI만이라 화면 문구 없음. 강화·소환 탭 문구는 M2(ui 레인)와 함께 `ship.`·`crew.`·`econ.` ARB에.

### 운영자 모드에서 불러보는 법
M1 범위: `OpGrant`(골드·젬·카드), `OpSetShip`, `OpSetCrew`, `OpAdvanceClock`(오프라인 확인)을 EconomySystem이 처리.

## 결정 (2026-10-14 사용자 승인)
- ① **카드 저장 = 계약 유지**: 카드를 받는 순간 등급별 경험치(`cardExp`)를 `CrewState.exp`에 적립하고, `cards`는 승급에 쓸 장수만 센다.
  `MergeAllCards`는 적립 경험치를 레벨로 바꾸고 승급 문(등급 마지막 레벨)에서 멈춘다(남는 경험치는 보존). 승급은 `cards`를 쓴다.
- ② **보스 카드 = 전투가 경제 함수 호출**: 경제가 `grantBossCards(state, ctx)`를 공개하고 전투가 보스 처치 순간 부른다. 계약 변경 없음.
- ③ **테이블 = 설계서 기준**: rarities 65/27/7/1, 승급 카드 3·6·10·20 + 증표 50, 승급 골드 = 처치 골드 × 100·300·1,000·3,000,
  레벨당 경험치 등급별 1·3·6·20·30. sim 뒤 4.3.3의 신화 조정은 따로 제안.

## 단계
- [x] 0. 스펙 승인 (사람) · 결정 ①②③
- [ ] 1. `ship_stats.dart` 순수 함수 + 테스트 → `docs/contracts/requests/economy-stats.md`로 S1에 시그니처 공유
- [ ] 2. 테이블 정리(rarities·growth) + 모델(`crew_tables.dart`) + `gen_tables`
- [ ] 3. UpgradePart (기준 1~4)
- [ ] 4. Summon + 천장 + receiveCard (기준 5~8, 11)
- [ ] 5. MergeAllCards · PromoteCrew (기준 9~10)
- [ ] 6. ClaimOffline + 보스 카드 (기준 12)
- [ ] 7. 운영자 명령 4종
- [ ] 8. `game_cli sim` + 7.2 리포트, check 스모크 활성화 (기준 13)

## 검증
- 단계마다 테스트 먼저(실패 확인) → 구현 → `tool\check.bat`. 커밋 전 `--full`.
- 테이블 변경 시 sim 리포트를 진척 문서에 첨부.

## 메모
- 경제가 쓰는 숫자는 전부 테이블에서(0·1 외 리터럴 금지).
- `crews.json`의 `family` 값은 건드리지 않는다(main에서 support→shock, `skill` 필드 추가 머지 예정).
