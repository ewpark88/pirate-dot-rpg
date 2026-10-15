# 스펙: economy 환생(보물지도)

- 상태: **승인됨** (2026-10-14, S1·사용자: ① 매번 전부 지급 ② RebirthDone 이벤트는 S1이 계약에 추가) · 레인: economy · 설계서 절: 4.5 ‘환생: 보물지도’, 7.2, 6.10 · 테이블: `meta.rebirth`
- 계약: 기존 `Rebirth`·`OpRebirthNow`·`OpReset` 명령, `Wallet.mapPieces`, `Progress.rebirths`를 쓴다. 계약 변경 없음.

## 목적
- 시원한가: 막혔을 때 한 번 누르면 조각이 쌓이고, 다시 시작해도 5분 안에 이전 최고의 30%까지 단숨에 회복.
- 단순한가: 버튼 하나, ‘지금 하면 조각 N개, 다음 조각까지 스테이지 M’만 보인다.
- 피로가 없는가: 선원·도감·젬·증표는 유지. 잃는 것은 스테이지·골드·배 강화뿐.
- 공정한가: 조각 공식과 보너스는 `meta.rebirth`에서만.

## 규칙
1. **해금**: 이번 회차 스테이지(`progress.stage`)가 `rebirth.minStage`(40) 이상일 때만 `Rebirth`가 동작. 아니면 무시.
2. **얻는 조각** `piecesFor(stage) = floor((stage − offset)^exponent)` (`offset` 35, `exponent` 1.4). 스테이지 40 → 9, 50 → 44, 100 → 344.
   - 기준 스테이지는 **이번 회차의 스테이지**(`progress.stage` — 한 회차 안에서는 줄지 않는다). 결정 필요 ①.
3. **초기화**: `progress` = 스테이지 1·파 0·파밍 아님·함성 0, `rebirths + 1`, `bestStage`는 유지(역대 최고). 골드 0, 배 강화 전부 0, 전장(`battle`)은 비운다.
   **유지**: 선원·카드·증표·도감·젬·소환 기록·천장·일일 값·버프·설정·튜토리얼(끝난 상태).
4. **보너스** `rebirthBonus(state, tables) = mapPieces × bonusPerPiece`(0.05, 합산). 전체 피해와 골드 획득의 ‘% 보너스 합’에 더한다(설계서 4.8 마지막 합).
   전투 적용은 전투 레인(CombatStats). 경제의 초당 골드 추정(오프라인·상자·sim)과 DPS 추정에도 같은 값을 더한다.
5. **이벤트**: `Rebirth` 처리 시 `SaveRequested('rebirth')`. 화면 연출용 이벤트는 계약에 없다 — 결정 필요 ②.
6. **미리보기** (UI 요청) `RebirthPreview rebirthPreview(state, tables)` — Rebirth 처리와 같은 계산:
   `{locked, minStage, currentPieces, gain, nextPieceInStages, bonusPerPiece, bonusNow, bonusAfter}`.
   - `locked` = stage < minStage. 잠겨 있어도 null이 아니라 값을 준다(‘스테이지 40에서 해금’ 표시용).
   - `nextPieceInStages` = gain이 1 늘어나는 가장 가까운 스테이지까지 남은 수.
7. **운영자**: `OpRebirthNow` = 해금 조건 무시하고 지금 환생(조각은 공식대로, 40 미만이면 0~). `OpReset` = 새 게임(시작 선원·튜토리얼 1부터, playerId·설정 유지).
8. **sim 정책** (설계서 7.2): 스테이지가 minStage 이상이고 한 벽(파밍)이 `meta.sim.rebirthWallSec`(제안 600초)를 넘으면 환생.
   지표 추가: ‘환생 뒤 이전 최고의 recoverTargetRatio(30%) 회복 시간’ 목표 ≤ `recoverTargetSec`(300초), 첫 환생 시점(참고).

## 수용 기준 (Given / When / Then)
1. Given 스테이지 39 When Rebirth Then 변화 없음.
2. Given 스테이지 50, 골드·배 강화 있음, 조각 3 When Rebirth Then 조각 3 + 44, 스테이지 1, 골드 0, 배 강화 0, rebirths +1, 선원·젬·증표·도감 그대로, bestStage 유지.
3. rebirthPreview(스테이지 50) = gain 44, nextPieceInStages = (gain 45가 되는 첫 스테이지 − 50), locked false · 스테이지 10이면 locked true, gain 0.
4. rebirthBonus(조각 10) = 0.5, 오프라인 초당 골드 추정이 조각 0일 때의 1.5배.
5. OpRebirthNow(스테이지 20) Then 환생됨(조각 0). OpReset Then 새 게임 상태(튜토리얼 1, 시작 선원).
6. sim: 하루 일정 60일에서 후반 벽 ≤ 20분, 환생 후 30% 회복 ≤ 300초.

## 문구 (ko / en)
코어만. 화면 문구는 ui 레인.

## 운영자 모드에서 불러보는 법
`OpJumpStage(60)` → 환생 버튼 미리보기 확인 → `Rebirth` 또는 `OpRebirthNow`.

## 결정 필요 (사람)
- ① 조각 기준: **이번 회차 스테이지로 매번 전부 지급**(설계서 문구 그대로, 같은 스테이지에서 반복 환생해도 매번 받음 — 반복 환생이 이득인지 sim으로 확인)
  vs **역대 최고를 넘긴 만큼만 지급**(`piecesFor(이번 스테이지) − piecesFor(이전 환생 때 기준)`, 반복 파밍 방지, 기록 필드가 필요 = 계약 변경).
- ② 환생 연출 이벤트(`RebirthDone(gain)`)를 계약에 추가할지 — 없으면 UI는 상태 변화(mapPieces·rebirths)로 연출.

## 결정 기록: 환생 3 (사용자 결정 2026-10-15, S1 경유) — c3 + f0 채택
근거: `docs/plans/active/economy-rebirth.md` ‘환생 3’ 비교표. 보스 카드 5종 × 빠른 항해 2종 변형 중 벗어남이 가장 적다(첫 신화 하나).
- **c3 반복 보스 카드** (economy): 환생 뒤 이미 깬 스테이지(잡는 보스 스테이지 < `bestStage`)의 보스는 `growth.bossCards.repeatEvery`(2)번째 스테이지마다 `repeatCount`(1)장. 역대 최고 스테이지의 보스와 첫 회차는 원래 장수(`countAt`).
  이유: 환생 회차마다 같은 보스 카드를 다시 받아 카드 수입이 회차 수만큼 곱해졌다(첫 신화 13일).
- **f0 빠른 항해** (battle, S1 구현): 환생 뒤 스테이지 ≤ ceil(`bestStage` × `waves.rebirthSkip.fraction`(0.3))은 파 `rebirthSkip.waves`(0)개 → 바로 보스. 파밍 중(보스 실패 뒤)에는 원래대로.
  이유: 초반 스테이지는 파 3개 + 이동이 시간 바닥이라 환생 보너스로 빨라지지 않는다(상대 회복 ≈ 1.0). 30% 회복 1,564초 → 163초.
- 남는 첫 신화(22일, 목표 28~56일)는 숫자(신화 승급 비용)로 맞춘다 — 아래 수용 기준 7.

수용 기준 추가:
7. Given 환생 1회, bestStage 50 When 스테이지 8 보스 처치 Then 카드 1장 · 스테이지 9 보스 Then 0장 · 스테이지 50 보스 Then `countAt(50)`장.
8. sim 하루 일정 60일: 첫 전설 1~4일, 승급 전설 4~8일, 첫 신화 28~56일, 환생 뒤 30% 회복 ≤ 300초.
