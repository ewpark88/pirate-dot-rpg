# 스펙: 전투 코어 M1 (무리·자동 공격·보스·파밍)

- 상태: **승인됨** (2026-10-14, 사용자) · 레인: battle (S1) · 설계서 절: 4.1, 4.3.2, 4.4, 4.8, 4.11
- 범위: 화면 없이 `CoreEngine`만으로 스테이지 진행 → 보스 → 성공/실패(파밍) → 재도전이 끝까지 돈다.
  스킬·궁극기 8계열의 고유 모양, 적 역할(분열·부활 등), 해역 보스 패턴은 **M3**로 미룬다.

## 목적
- 시원한가: 무리가 몰려오고 범위 공격 한 방에 여러 마리가 함께 터진다(동시 처치 이벤트).
- 단순한가: 플레이어 입력은 `ChallengeBoss`, `TriggerUltimate` 두 개뿐. 나머지는 전부 자동.
- 피로가 없는가: 보스 실패 시 벌이 아니라 파밍으로 자연스럽게 넘어간다.
- 공정한가: 같은 시드 + 같은 명령 = 같은 결과. 모든 수치는 테이블에서 읽는다.

## 규칙

### 1. 전장과 진행
- 좌표: `BattleView` 계약대로 전장 x 0~148(논리 320×180). 배는 왼쪽 고정, 적은 오른쪽 끝에서 생성되어 왼쪽으로 이동.
- 한 스테이지 = 무리 `wavesPerStage`(3)파 → 보스. 파를 모두 잡으면 `WaveCleared`, 다음 파는 `travelSec`(2초) 뒤 생성.
- 파밍 중(`progress.farming == true`)에는 보스 없이 같은 스테이지의 무리 파가 계속 온다.

### 2. 무리 생성
- 한 파 마리 수 = `waves.mobCountAt(stage)`.
- 단일 몬스터 HP = `hpBase × hpGrowth^(stage-1)`, 마리당 HP = 단일 HP × `waveHpPoolFactor` × 적 `hpScale`.
- 적 종류: `regions.regionAt(stage).enemies` 중 Rng로 고름. 층(layer)·속도·hpScale은 `regions.enemies`.
- 처치 골드 = `goldBase × goldGrowth^(stage-1)` (화물칸·동시 처치 보너스 적용 전 값. 화물칸 배율은 경제 레인 함수가 생기면 그것을 쓴다).

### 3. 이동과 배 피해
- 적은 매 틱 `speed × tickMs/1000`만큼 왼쪽으로. 배의 오른쪽 끝(전장 x 하한 + 배 폭)에 닿으면 멈추고
  `attackBase × attackGrowth^(stage-1)`의 피해를 1초마다 준다 → `ShipDamaged`.
- 배 HP가 0이 되면: 보스전이면 보스 실패와 같게 처리, 무리전이면 배 HP를 가득 채우고 현재 파를 처음부터(벌 없음).

### 4. 자동 편성
- 후보 = 보유 선원. 파워 = 레벨 배율 × 승급 배율(4.8). 파워 내림차순, 같으면 crews.json 순서.
- 같은 계열은 최대 `maxSameFamilyInFleet`(2)명, 슬롯 수 = 현재 배 등급의 `slots`.
- 선장 = 출전 선원 중 등급이 가장 높은 선원(같으면 파워 순). `BattleView.captainId`.
- 편성은 전투 시작·스테이지 시작·`OpSetFleet` 때 다시 계산한다.

### 5. 기본 공격 (계열 8종, `skills.json`의 `attack`)
| 모양 | 대상 선정 | 맞는 적 |
| --- | --- | --- |
| circle | 적이 가장 많이 모인 지점(cluster) | 반경 안 전부 |
| single | 가장 가까운 적 | 1마리 |
| line | 가장 가까운 적 방향 | 폭 안의 한 줄 전부 (관통 감쇠) |
| chain | 가장 가까운 적부터 다음으로 가까운 적 | `chains`회 (연쇄 감쇠, 최대 `chainMax`) |
| random | 무작위(공중 적 우선) | `count`마리 |
| cone | 배 앞 부채꼴 `range`·`angleDeg` | 부채꼴 안 전부 |
| ship | 배 자신 | 피해 없음 (충격/지원 효과는 M3) |
- 발사 간격은 계열별 고정값(설계서 4.3.2) ÷ 공격 속도 배율(돛, 최대 `attackSpeedMax`).

### 6. 피해 공식 (설계서 4.8, 곱셈 5항 고정)
`피해 = 기본 × 레벨 배율 × 승급 배율 × 배 등급(1+damageBonus) × (1 + % 보너스 합)`
- 기본 = 대포 공격력(`ship_parts.cannon`) ÷ 이 공격의 발사 수(예산 유지).
- 치명타: 확률 = 망루(최대 `critChanceMax`), 배율 `critMultiplier`. 치명타는 Rng로 정하고 `Damage.crit=true`, `HitStop(crit)`.
- 범위: 한 번에 `aoe.fullDamageTargets`(6)마리를 넘으면 7번째부터 `overflowDamage`(50%). 2마리 이상이면 `AoeDamageSum`.
- 연쇄·관통: 한 번 튈 때마다 `chainFalloff`(10%) 감소.
- 경제 레인이 강화 효과 함수를 내기 전에는 `battle/`에 테이블 공식을 직접 계산하는 임시 함수를 두고, 나오면 교체한다.

### 7. 처치·동시 처치·함성 게이지·히트스톱
- 처치 → `Kill(gold)`. 지갑에 골드를 더하는 것은 경제 레인 담당이므로 전투는 이벤트만 낸다 (아래 미결 2).
- 동시 처치: 마지막 처치 후 `multiKill.windowSec` 안에 이어진 처치를 묶는다. 창이 닫힐 때 2마리 이상이면
  `MultiKill(count)`, 골드 보너스 `goldBonusPerKill × count`. 4마리 이상이면 `HitStop(multiKill4)`.
- 처치마다 `progress.rage += rage.perKill`. 가득 차면 `autoTrigger`일 때 자동, 아니면 `TriggerUltimate`로 발동 →
  `UltimateCast` + `HitStop(ultimate)` + 화면의 모든 적에게 피해(M1은 공통 모양, 계열별 모양은 M3). 게이지 0으로.
- 히트스톱 틱 = `juice.hitStopMs[이유] / tickMs` (올림).

### 8. 보스
- `wavesPerStage`파를 잡으면 보스 생성 → `BossSpawned(kind, timeLimitTicks)`. HP = 단일 HP × `boss.hpMultiplier`.
- 타이머 `boss.timeLimitSec` → `bossTicksLeft`가 매 틱 1 감소.
- 시간 안에 처치 → `BossCleared(stage, gems)`, 스테이지 +1, `wave=0`, 배 HP 회복. (젬·카드 지급은 경제 레인이 이벤트를 받아 처리)
- 시간 초과 → `BossFailed(stage)`, `farming=true`, 보스 제거, 무리 파 계속.
- `ChallengeBoss`(파밍 중) → 현재 파를 정리하고 바로 보스 생성, `farming=false`.

### 9. 운영자 명령
`OpJumpStage`, `OpSetWave`, `OpSpawnBoss`, `OpSetInvincible`, `OpZeroCooldown`, `OpSetFleet`를 처리한다.
`OpCastSkill`은 스킬 구현(M3)과 함께.

### 10. 결정론과 내부 상태
- 적의 실제 HP(BigNum)·발사 쿨타임 초·동시 처치 창 같은 시뮬 내부 값은 `BattleSystem` 인스턴스가 들고,
  매 틱 `GameState.battle`(BattleView)로 투영한다. 계약(`contracts.dart`)은 바꾸지 않는다.
- `OpLoadState`·세이브 불러오기로 BattleView가 내부 상태와 어긋나면 현재 파를 처음부터 다시 만든다.
- 난수는 `ctx.rng`만 쓴다. 같은 시드 → 같은 이벤트 목록(리플레이 테스트).

## 수용 기준 (Given / When / Then)
1. Given 스테이지 1 새 게임 When 엔진 시작 Then 1틱 안에 `mobCountAt(1)`마리가 오른쪽 끝에 생기고 HP 합 = 파 HP 풀 — 단위 테스트
2. Given 적 1마리 When 아무 공격도 없이 진행 Then 배에 닿은 뒤 `ShipDamaged`가 나온다 — 단위 테스트
3. Given 선원 7명(같은 계열 3명 포함), 쪽배 When 편성 Then 3명, 같은 계열 ≤2, 선장 = 최고 등급 — 단위 테스트
4. Given 적 8마리 한곳에 모임 When circle 공격 Then 8마리 맞고 7·8번째는 50% 피해 + `AoeDamageSum` — 단위 테스트
5. Given chain 공격 When 4번 튐 Then 피해가 매번 10%씩 줄어든다 — 단위 테스트
6. Given 0.5초 안에 5마리 처치 When 창이 닫힘 Then `MultiKill(5)` + `HitStop` — 단위 테스트
7. Given 함성 게이지 가득, autoTrigger When 다음 틱 Then `UltimateCast`, 게이지 0 — 단위 테스트
8. Given 약한 편성 스테이지 5 When 3파 처치 + 31초 Then `bossActive=false, farming=true, stage=5`, `ChallengeBoss` → `bossActive=true`
   — `scenarios/boss_timeout_farming.yaml` skip 해제
9. Given 충분히 강한 편성 When 보스 처치 Then `BossCleared`, 스테이지 +1, wave 0 — `scenarios/boss_clear_advances.yaml`
10. Given 같은 시드·같은 명령 When 두 번 600틱 Then 이벤트 JSON이 완전히 같다 — 단위 테스트
11. Given 숫자 리터럴 When check Then `battle/`에 0·1 외 리터럴 없음 — 하네스

## 문구 (ko / en)
M1은 새 화면 문구 없음. 동시 처치 문구 키(`battleCombo*`)는 이미 `waves.json`·battle ARB에 있다.

## 운영자 모드에서 불러보는 법
`OpJumpStage(37)` → `OpSpawnBoss` → `OpSetInvincible(true)`. 화면 패널 연결은 UI 레인(M2).

## 결정 (2026-10-14 승인 때)
1. **8번째 계열 = `shock`** (설계서 기준, 8계열 × 5명 유지). 기본 공격은 모두 충격파(밀어내기, 낮은 피해).
   스킬은 선원별로 다를 수 있다 — `crews.json`의 선택 필드 `skill`이 계열 스킬을 덮어쓴다.
   톡·뽀뽀·코리 = 계열 스킬 `shock_wave`(화면 밀어내기), 쿡·램프 = `support_rally`(배 회복 + 공격 속도 버프).
   스킬 동작 자체는 M3. `tool/import_crews.dart`는 도트 팩의 `support`를 `shock`로 바꾸고 기존 `skill` 필드를 보존한다.
2. **골드·젬은 전투가 직접 지갑에 더한다.** 처치 골드 = 기본 골드 × 화물칸 배율 (+ 동시 처치 보너스), 보스 젬 = `boss.gems`.
   배율 계산은 지금은 `battle/combat_stats.dart`의 임시 함수, 경제 레인이 강화 효과 함수를 내면 그것으로 바꾼다.
   보스 카드 지급은 경제 레인(소환·카드 규칙과 함께).
3. **테이블에 추가하는 값**: `skills.json` 계열마다 `attack.intervalSec`(설계서 4.3.2), `attack.power`(계열별 한 발 배율, 밸런스 시뮬로 조정),
   `attack.excludeLayers`(수중·강습은 공중 적을 못 맞힘), 관통 `pierce`, `rage.ultimateMultiplier`.
   `waves.json`에 `field`(전장 크기·배 위치·생성 위치·층별 y·접촉 피해 간격)와 `boss.speed`.
4. **M1에서 단순화**: 발사체 비행 시간 없음(발사 틱에 피해, 렌더가 날아가는 연출), 치명타는 발사 1회당 1번 굴림,
   장판 지속 피해·기절·스킬은 M3. 소환 확률 불일치(`rarities.json` 60/28/10/2 vs 설계서 65/27/7/1)는 경제 레인에 넘긴다.
