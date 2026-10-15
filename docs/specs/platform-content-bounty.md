# 기획: 현상금 사냥 (일일 보스)

- 상태: 초안 (2026-10-15, S5) · 개요 `platform-content-overview.md` (우선순위 2, 규모 L)
- 한 줄: 쌓이는 티켓으로 **요일 현상금 보스**를 30초 안에 잡으면 그 요일 보상(젬·카드·선물·지도 조각). 한 번 깬 단계는 **소탕**(전투 없이 즉시).
- 피로 규칙: 티켓은 하루 3장씩 **최대 9장까지 쌓인다**(3일 안 들어와도 손해 없음) · 소탕으로 1장 1초 · 실패해도 티켓을 돌려준다 · 팝업·알림 없음.

## 1. 규칙
1. **티켓**: 기기 현지 날짜가 바뀔 때마다 `bounty.ticketsPerDay`(3)장 충전, 최대 `bounty.ticketCap`(9). 광고로 하루 `ads.placements[bountyTicket].dailyLimit`(1)장 추가(상한 넘어도 받음 = 최대 10).
2. **요일 보스**: 월~토는 요일마다 보스 1종(표 `days`). **일요일은 6종 중 아무거나**. 보스 그림은 기존 해역 보스를 '현상금 수배' 버전으로(새 그림 없음).
3. **단계(난이도)**: 보스마다 1단계부터. 단계 t의 보스 HP = 스테이지 `t × bounty.stagePerTier`(10)의 해역 보스 HP × `bounty.hpMultiplier`(1.5). 단계 t를 깨면 t+1이 열린다. 단계 상한 `bounty.maxTier`(30).
4. **도전**: 티켓 1장 → 현상금 전투(아래 2). 30초(`waves.boss.timeLimitSec`) 안에 처치 = 성공 → 단계 보상, 그 단계 '깸' 기록. 실패 = **티켓 반환** + 입힌 피해 비율만큼 진행 막대(다음 도전에 참고용, 보상 없음).
5. **소탕**: 깬 단계 중 최고 단계를 티켓 1장으로 즉시 보상(전투 없음). '다 쓰기' 버튼 = 남은 티켓 모두 소탕.
6. 본 전투(스테이지 진행)는 현상금 전투 동안 **일시정지**(오프라인 시간으로 세지 않음). 현상금 전투 중 앱을 뒤로 보내면 실패 처리 + 티켓 반환.

## 2. 현상금 전투 (battle)
- 같은 전투 엔진의 **모드 하나 추가**: 적 = 현상금 보스 1마리(+ 보스 기믹 그대로: 보호막·용암·촉수 …), 무리 없음, 30초 타이머, 내 출전 선원·배 강화·스킬·궁극기 그대로.
- 끝나면 본 전투로 복귀(같은 스테이지·같은 파 처음부터, 환생 복귀 규칙과 같게).
- 결정론: 현상금 전투 난수는 `rngSeed`에서 갈라 쓴다(리플레이 가능).

## 3. 테이블 — `packages/game_data/tables/bounty.json` (economy)
```json
{
  "ticketsPerDay": 3, "ticketCap": 9, "stagePerTier": 10, "hpMultiplier": 1.5, "maxTier": 30,
  "days": [
    {"weekday": 1, "boss": "giant_hermit",   "reward": {"type": "gems",      "base": 10, "perTier": 1}},
    {"weekday": 2, "boss": "thunder_ray",    "reward": {"type": "cards",     "base": 2,  "perTier": 0.2}},
    {"weekday": 3, "boss": "iceberg_walrus", "reward": {"type": "gifts",     "base": 2,  "perTier": 0.1}},
    {"weekday": 4, "boss": "lava_whale",     "reward": {"type": "gems",      "base": 10, "perTier": 1}},
    {"weekday": 5, "boss": "kraken",         "reward": {"type": "cards",     "base": 2,  "perTier": 0.2}},
    {"weekday": 6, "boss": "ghost_admiral",  "reward": {"type": "mapPieces", "base": 1,  "perTier": 0.1}},
    {"weekday": 7, "boss": "*",              "reward": "asBoss"}
  ]
}
```
- 보상량 = `floor(base + perTier × (t − 1))`. 카드 = 보유 선원 중 무작위(결정론), 선물 = `crew-bond`의 선물 아이템(그 기획 전에는 젬 10으로 대체), 지도 조각 = 환생 보너스 조각(설계서 4.5)에 직접 더함.
- 균형(초기값, economy가 sim으로): 하루 3장 × 젬 요일 최고 단계 ≈ 하루 **+30~120 젬** — 개요의 '하루 젬 ≤ 140' 안에 들어오게 `perTier` 조정.
- `ads.json` placements에 `{"id": "bountyTicket", "dailyLimit": 1, "reward": {"type": "bountyTicket", "value": 1}}`.

## 4. 세이브 (다음 버전)
```json
"bounty": {"tickets": 3, "refilledOn": "2026-10-15", "cleared": {"giant_hermit": 4, "thunder_ray": 0}, "progress": {"giant_hermit": 0.62}}
```
- `refilledOn`: 마지막 충전 현지 날짜(일일 초기화와 같은 비교). 날짜가 여러 날 지나 있으면 그 일수 × 3장(상한까지).
- `cleared`: 보스별 깬 최고 단계. `progress`: 다음 단계 최고 피해 비율(UI 막대). 마이그레이션: 티켓 3, 나머지 빈 값.

## 5. 명령 · 이벤트
- `StartBounty(bossId, tier)` — 오늘(일요일은 아무) 보스, 열린 단계, 티켓 ≥ 1일 때만. 티켓 −1, 현상금 모드로.
- `SweepBounty(bossId, count)` — 깬 최고 단계로 count장 소탕(티켓 부족하면 있는 만큼).
- `RetreatBounty()` — 도중 포기 = 실패 처리(티켓 반환).
- 이벤트: `BountyStarted(bossId, tier, timeLimitTicks)` · `BountyCleared(bossId, tier, reward)` · `BountyFailed(bossId, tier, damageRatio)` · `BountySwept(bossId, tier, count, reward)` · `BountyTicketsRefilled(count)`.
- 광고: `GrantAdReward(AdPlacement.bountyTicket)` → 티켓 +1(경제가 일일 한도 확인).

## 6. UI 화면 (ui)
1. **항해 탭 카드 '현상금 사냥'**(보물지도 카드 위): 오늘 보스 초상·이름·요일 보상 아이콘, 티켓 `3/9`, [도전] [소탕 ×N] 버튼. 티켓 0이면 [광고로 1장](오늘 안 봤을 때만).
2. **현상금 시트**(카드 누르기): 보스 7칸(오늘 강조, 일요일은 전부 열림), 단계 선택(− t +, 깬 최고 단계 표시), 다음 단계 진행 막대.
3. **현상금 전투 화면**: 본 전장 그대로 + 상단 '현상금' 띠·타이머, [후퇴] 버튼(선원 줄 오른쪽, 궁극기 옆). 끝나면 결과 작은 창(성공: 보상 숫자 올라가기 / 실패: '티켓은 돌려받았어요 · 피해 62%').
4. 빨간 점: 항해 탭 아이콘 — 티켓이 상한(9)일 때만(넘치기 직전 = 지금 쓰면 이득). 티켓이 있다는 이유만으로는 켜지 않는다.

## 7. 렌더 (render/art)
- 현상금 전투 시작 컷인: **수배 포스터**(양피지 + 보스 초상 + 현상금 숫자) 0.8초 — 기존 해역 보스 컷인(`fx_map.cutIn`)에 포스터 틀 1장(art).
- 보스 기믹 연출은 기존 그대로. 타이머 표시는 캔버스 HUD(보스 타이머 자리).
5. **태블릿(800×1280, dpr 2)**: 현상금 시트의 보스 7칸은 한 줄(폰은 4+3 두 줄), 단계 선택은 옆에. 항해 탭 카드는 폭 최대 560dp.

## 8. 수용 기준
1. Given `refilledOn` 3일 전·티켓 2 When 현지 날짜 바뀐 뒤 첫 틱 Then 티켓 9(상한), `BountyTicketsRefilled(7)`.
2. Given 수요일 When `StartBounty(thunder_ray, 1)`(화요일 보스) Then 거절(로그), 티켓 그대로. 일요일엔 허용.
3. Given 단계 1 미클리어 When `SweepBounty` Then 거절.
4. Given 단계 3 도전, 30초 안에 처치 When 종료 Then `BountyCleared`, 보상 = floor(base + perTier×2), `cleared` = 3, 본 전투가 같은 스테이지에서 재개.
5. Given 시간 초과 When 종료 Then 티켓 반환, `progress`에 피해 비율, 보상 없음.
6. Given 같은 rngSeed·명령 When 두 번 리플레이 Then 같은 결과(카드 선원 포함).
7. Given 현상금 전투 중 When 앱이 뒤로(pause) Then 실패 처리·티켓 반환, 다시 열면 본 전투.
8. Given 광고 보상 1회 사용 When 같은 날 다시 Then 버튼 없음.
9. 골든: 항해 탭 카드·현상금 시트 ko/en, 384dp·360dp 넘침 없음. 시나리오 리플레이 `scenarios/bounty_*.json` 2개(성공·실패).

## 9. 레인 분담
| 레인 | 할 일 |
| --- | --- |
| battle | 현상금 전투 모드(보스 1·타이머·종료·본 전투 복귀), 결정론 분기, 시나리오 |
| economy | `bounty.json`, 티켓 충전·소탕·보상 지급, 광고 장치, 젬 sim |
| ui | 항해 탭 카드, 현상금 시트, 전투 띠·후퇴 버튼, 결과 창, 빨간 점 규칙 |
| render/art | 수배 포스터 컷인(그림 1장 + 연출) |
| platform | Analytics `bounty_start/clear/fail/sweep`, 스토어 문구 한 줄 |
| S1 | 계약(명령 3·이벤트 5·`AdPlacement.bountyTicket`·세이브), 리뷰 |

## 10. 열린 질문
- 일요일 '아무 보스' 대신 '이번 주 덜 깬 보스 추천'을 띄울지(정보만, 강요 없음).
- 단계 상한 30 이후(스테이지 300 = 게임 끝)의 보상 정체 — 2차에 '무한 단계'(HP ×1.1씩) 검토.
