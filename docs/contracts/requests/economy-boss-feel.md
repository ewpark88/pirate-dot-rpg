# 계약 변경 요청: 보스전 손맛 (economy, 2026-10-17) — S1 승인

사용자: '핵앤슬래시 플레이를 하고 싶은데 보스전도 너무 밋밋해'. S1 승인(기다리지 말고 구현, 이 문서는 기록용).

## 추가 (모두 선택 키 — 세이브 버전 그대로)

| 종류 | 이름 | 내용 |
| --- | --- | --- |
| 이벤트 | `BossBarBroken(tick, enemyId, bar, barsLeft, x, y)` | 보스 체력 층이 깨짐(마지막 층 = 처치는 없음) |
| 이벤트 | `UltimateCast.manual`(bool, 기본 false) | 선장 필살기를 버튼으로 썼다 |
| 명령 | `TriggerUltimate()`(기존 — 이제 처리됨) | 게이지가 가득이면 다음 틱에 필살기 |
| BattleView | `captainGauge`(0~1) | 1이면 버튼 빛남 |
| EnemyView | `bossBars` · `bossBarsLeft` | 층 수 · 남은 층(1 = 층 없음) |
| Settings | `autoUltimate`(기본 true) | 끄면 버튼으로만 |

## 규칙 (표 키)

- `waves.boss.bars` {byStage: 1~29 3층 · 30~79 4층 · 80+ 5층, staggerSec 1, staggerDamageMul 1.3}: 층이 깨지면 1초 비틀(기절 = 공격 멈춤 + 받는 피해 × 1.3). 기존 브레이크(skills.bossBreak, 피해 × 3)와 별개이고, 비틀 동안은 브레이크 게이지가 안 쌓인다.
- `meta.captainSkill` {killGain 0.004, bossDamageGain 1.2, rushSec 3, attackSpeedMul 2}: 처치 1마리 +0.004, 보스 HP 100% 깎을 때 +1.2. 가득이면 선장 궁극기 효과(피버 첫 일격과 같은 castUltimate) + 함대 3초 폭주(공격 속도 × 2). 폭주 중엔 게이지가 안 찬다. 피버 첫 일격은 그대로(게이지와 별개).
- 관통(S1 설계 '공속 ×2·관통')은 1차에 빠짐 — 공속만. 탄 관통은 계열마다 탄 구조가 달라 다음 단계.
- 보스 처치 시간은 바꾸기 전 ±10%(3자 균형 guard) — BALANCE.md 기록.

담당: 엔진·표 S2 / 연출(층 깨짐·폭주 오라) S3 / 버튼·게이지·설정 토글 S4.
