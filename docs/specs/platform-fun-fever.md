# 기획: 피버 타임 + 즉석 도전

- 상태: 초안 (2026-10-15, S5, 사용자 결정 '지루함 해소 3종' ②)
- 한 줄: 처치가 쌓이면 **피버 10초**(공격 2배·금화 비·화면 연출)가 자동으로 터지고, 몇 분마다 **즉석 도전**('30초 안에 50마리')이 떠서 평소 전투에 작은 목표를 준다.
- 피로 규칙 대응: 둘 다 **자동**(누를 것 없음). 도전은 실패해도 잃는 것 없음, 팝업 없음(전장 위 작은 띠), 횟수·연속 기록 없음. 흔들림·번쩍임 끄기 설정을 따른다.

## A. 피버 타임

### 규칙
1. **피버 게이지**(0~1): 처치 1마리 +`fever.perKill`(1/120), 동시 처치는 마리당 ×`fever.multiKillBonus`(1.5), 보스 처치 +0.25. 시간이 지나도 줄지 않는다.
2. 게이지가 차면 **자동 발동** 10초(`fever.durationSec`): 내 선원 피해 ×`fever.damageMultiplier`(2), 처치 골드 ×`fever.goldMultiplier`(1.5), 하늘에서 금화 비(연출 + 처치마다 금화 튀김).
3. 피버 중엔 게이지가 안 찬다. 끝나면 0부터. 보스전 중에도 발동한다(보스 타이머에 도움 — 막힘 완화).
4. 궁극기(함성 게이지)와 별개: **함성 = 선장 궁극기 한 방**, **피버 = 10초 전체 강화**. 두 게이지가 헷갈리지 않게 UI는 함성은 궁극기 버튼 둘레, 피버는 전장 맨 위 얇은 막대로 나눈다.
5. 오프라인 계산엔 넣지 않는다(오프라인은 평균값, 피버는 접속 중 재미).

### 테이블 — `juice.json`·`meta.json`이 아닌 새 `fever.json` (economy)
```json
{"perKill": 0.00833, "multiKillBonus": 1.5, "bossKill": 0.25, "durationSec": 10,
 "damageMultiplier": 2.0, "goldMultiplier": 1.5}
```
- 균형: 보통 전투에서 약 **90~120초에 한 번**(무리 10마리 × 파 3 × 스테이지 …) — sim으로 확인. 피버 10초가 1~2분마다면 '지루함' 간격과 맞는다.

### 계약 · 연출
- 세이브: `progress.fever`(0~1, 선택 키). 피버 진행 중은 저장 안 함.
- 이벤트: `FeverStarted(untilTick)` · `FeverEnded()` · (게이지는 `BattleView.fever` 필드 0~1).
- render: 전장 가장자리 금빛 테두리 펄스, 하늘 금화 비(파티클, 절전이면 ½), 피해 숫자 금색, 피버 시작 0.3초 슬로모 + 'FEVER!' 도트 글자(렌더 캔버스, 문구 아님 — 숫자·아이콘만이면 더 좋음). 효과음 `fever_start`(오디오 후보표에 추가).
- ui: 전장 위 얇은 피버 막대(캔버스 HUD로 그려도 됨 — render가 정하면 ui는 없음).

### 수용 기준
1. Given 게이지 0 When 120마리 처치 Then `FeverStarted` 1회, 10초 동안 피해 2배(시나리오 리플레이로 처치 시간 비교).
2. Given 4마리 동시 처치 When 처리 Then 게이지 += 4 × perKill × 1.5.
3. Given 피버 중 When 처치 Then 게이지 그대로 0.
4. Given 흔들림·번쩍임 끔 When 피버 Then 테두리 펄스·슬로모 없음, 금화 비는 있음.
5. 성능: 피버 10초 동안 부하 장면 p95 ≤ 16.7ms(기존 기준).

## B. 즉석 도전

### 규칙
1. 3~5분(`challenges.intervalSec`)마다 도전 1개가 전장 위 띠로 뜬다(보스전·피버·돌발 이벤트 중엔 미룸).
2. 종류(가중 추첨, 결정론):
   - `kills`: '30초 안에 N마리'(N = 그 스테이지 30초 평균 처치 × 1.3)
   - `combo`: '동시 처치 5마리 이상 2번'(45초)
   - `noHit`: '20초 동안 배 체력 안 깎이기'
   - `ultimate`: '궁극기로 10마리'(함성 게이지 80% 이상일 때만 나옴)
3. 성공: 작은 보상(골드 꾸러미 = 1분 처치 골드, 또는 피버 게이지 +0.3, 또는 젬 1~2). 실패: 띠가 조용히 사라짐 — **보상·벌칙 없음**.
4. 목표치는 그 순간 화력으로 계산해 '조금 힘 내면 되는' 수준(성공률 목표 60~70%, sim).

### 테이블 — `challenges.json` (economy)
```json
{"intervalSec": [180, 300],
 "kinds": [
   {"id": "kills", "weight": 40, "sec": 30, "targetFactor": 1.3, "reward": {"type": "goldMinutes", "value": 1}},
   {"id": "combo", "weight": 25, "sec": 45, "multiKill": 5, "times": 2, "reward": {"type": "fever", "value": 0.3}},
   {"id": "noHit", "weight": 20, "sec": 20, "reward": {"type": "goldMinutes", "value": 1}},
   {"id": "ultimate", "weight": 15, "sec": 20, "kills": 10, "minRage": 0.8, "reward": {"type": "gems", "value": 2}}
 ]}
```

### 계약 · UI
- 세이브: 없음(진행 중 도전은 저장 안 함, `nextAtTick`만 `seaEvents`와 같은 방식으로 선택 키).
- 이벤트: `ChallengeStarted(id, target, untilTick)` · `ChallengeProgress(id, value)`(틱마다 아님 — 바뀔 때) · `ChallengeEnded(id, success, reward)`.
- ui: 전장 위 띠(아이콘 + '30초 안에 37/50' + 남은 막대). 성공 시 띠가 금색으로 바뀌고 보상 숫자가 1초 떠오름. 실패는 그냥 접힘.
- **태블릿**: 띠는 게임 영역(320×180) 폭 기준 가운데 — 넓은 화면에서 양옆으로 늘어나지 않게.

### 수용 기준
1. Given 같은 rngSeed When 30분 시뮬 Then 도전 6~10개, 간격 180~300초, 결정론.
2. Given kills 도전 When 시간 안에 목표 Then `ChallengeEnded(success)` + 1분 처치 골드. 못 채우면 보상 0, 다른 상태 변화 없음.
3. Given 함성 50% When 추첨 Then `ultimate` 종류는 나오지 않음.
4. sim: 성공률 60~70%(스테이지 20·80·200 표본).

## 레인 분담
| 레인 | 할 일 |
| --- | --- |
| battle | 피버 게이지·발동·배수, 도전 진행 판정(처치·동시 처치·피격·궁극기), 미룸 규칙 |
| economy | `fever.json`·`challenges.json`, 보상 지급, 목표치 계산, sim(피버 주기·성공률) |
| render/art | 피버 테두리·금화 비·슬로모·금색 숫자, `fever_start` 효과음 후보 |
| ui | 도전 띠·진행·성공 표시 |
| S1 | 계약(`BattleView.fever`, 이벤트 5, 세이브 선택 키) |
