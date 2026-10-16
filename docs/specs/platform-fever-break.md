# 기획 메모: 궁극기 제거 → 피버 첫 일격 + 보스 브레이크 (S5)

- 사용자 직접 지시(2026-10-17): "궁극기를 제거하고 위 제안한 것 중에 1 + 2로 진행." 근거 — 궁극기(분노)와 피버가 둘 다 '처치로 차오르고 → 자동으로 터지는 큰 한 방'이라 겹치고 조잡하게 보인다.
- 엔진: review/fever-break 2b5955d(S5). 수치 S2, 연출 S3, UI S4.

## 1. 피버에 흡수
- 분노 게이지·궁극기 버튼 없음. 처치는 피버 게이지만 채운다.
- 피버가 켜지는 순간(첫 틱) **선장 계열 궁극기 효과가 한 번** 터진다 — 화면 전체 피해(ultimateMultiplier) + 계열 효과(해일·회복 등). 이벤트는 UltimateCast 그대로(렌더 해일 재사용). 한 판의 절정이 '피버 시작' 하나로 모인다.
- 정리(S2): skills.json rage 항목, 즉석 도전 'ultimate'(분노 조건), progress.rage·BattleView.rage(세이브 정리 — 지금은 항상 0). 계열 ultimate 정의는 피버 첫 일격이 쓰므로 남긴다.
- UI(S4): HUD 분노 게이지·궁극기 버튼 제거. 연출(S3): fx_map ultimates를 '피버 시작 일격'으로 다듬기(피버 금빛 연출과 겹치게).

## 2. 보스 브레이크 게이지
- 보스에 기절·둔화·취약이 늘어난 초, 밀림·끌림 거리만큼 게이지가 찬다(skills.json bossBreak 가중치). 가득 차면 **breakSec 동안 쓰러져(기절) 받는 피해 × damageMul**(제안 3). 쓰러진 동안은 안 쌓이고, 일어나면 0부터.
- 목적: 지금 보스에게 제어가 절반만 들어가(bossControlFactor 0.5) 약한 제어형 선원(king·pingu·walrus 등)이 보스전에서 쓸모를 얻는다.
- 표(S2, 제안 출발값): stunPerSec 0.35 · slowPerSec 0.05 · vulnerablePerSec 0.05 · pullPerPx 0.008 · breakSec 3 · damageMul 3 → sim으로 '보스 30초 안 1~2번 브레이크(제어 편성)·0~1번(제어 없는 편성)'.
- 계약: EnemyView.breakRatio(0~1)·broken(선택 키), 이벤트 BossBroken(enemyId, ticks, x, y). UI(S4): 보스 머리 위 브레이크 막대·'BREAK!'. 연출(S3): 쓰러짐(옆으로 기울어 물보라)·피해 숫자 크게.

## 수용 기준
1. 분노가 쌓이지 않고 TriggerUltimate는 무시된다. 피버 하나에 첫 일격 하나.
2. 브레이크: 가중치대로 차고, 가득이면 breakSec 기절 + 피해 × damageMul, 쓰러진 동안 안 쌓임, 표 없으면 꺼짐.
3. sim: 제어 편성의 보스 처치 시간이 제어 없는 편성과 ±15% 안(지금은 제어 편성이 느림).
