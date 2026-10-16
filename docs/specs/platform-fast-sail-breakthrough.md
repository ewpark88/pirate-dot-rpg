# 기획: 빠른 항해 돌파 — 환생 뒤 연속 보스를 '순간 돌파' 쇼로 (S5 리드)

- 상태: 사용자 결정(2026-10-16, S1 중계) → 착수 · 엔진 S5 · 수치 S2 · 연출 S3 · UI S4
- 사용자: "보스는 나오지만 임팩트 효과가 빠르게 나오면서, 환생 직후에는 '당신은 강해져서 빠른 항해로 순간 돌파합니다'. 꿈과 희망을 심어 주는 웅대한 애니메이션과 함께 빠른 항해 돌파 이벤트. 보스가 연속으로 나오면서 격파하는 쾌감."
- 지금: 환생 뒤 bestStage × fastSailFraction(0.55 + 상점) 이하 스테이지는 무리 0파 → 보스만(waves.rebirthSkip.waves 0). 보스는 보통 보스처럼 멀리서 걸어와 30초 타이머 — 같은 보스가 수십 번 느리게 반복된다.

## 규칙
1. **구간**: 환생 뒤 빠른 항해 범위에 들어서면 `FastSailStarted(from, to)` — from = 지금 스테이지, to = 범위 끝. 범위를 벗어나면(to 보스 격파) `FastSailEnded`.
2. **리듬**: 구간 안 보스는 standoff 원에 바로 등장(걸어오지 않음), 이동 간격 `travelSec` 0.3초. 등장 뒤 `breakSec`(1.5초, 표 1.2~2) 안에 못 잡으면 **돌파 사격** — 출전 선원 일제 사격 연출 + 남은 HP 전부 피해(`BreakthroughStrike`). 선원이 먼저 잡으면 그때 격파. 결과: 스테이지당 약 1.5~1.8초.
3. **보상**: 보스 격파 보상은 보통과 같다(골드·젬·카드·배 등급). 구간 동안 합을 모아 `FastSailEnded`에 요약(돌파 스테이지 수·골드·젬).
4. **배**: 피버 질주처럼 앞쪽 적이 빨리 다가오고(forwardBoost) 배는 좌우 S자(meta.fever.weave 재사용). 피버 게이지는 구간 동안 멈춤(쇼와 겹치지 않게).
5. **건너뛰기**(2회차부터, S4 버튼): `SkipFastSail` → 남은 스테이지 보상을 한 번에 받고 to+1 스테이지로. 같은 `FastSailEnded`(skipped true).
6. 현상금·돌발 이벤트는 구간 동안 생기지 않는다.

## 계약 (S5 → S2 검토)
- 이벤트
  - `FastSailStarted(from, to)`.
  - `BreakthroughStrike(stage, bossId, x, y, combo)`: 격파 순간(선원이 잡아도 같은 이벤트) — combo = 이번 구간 연속 격파 수 1, 2, 3….
  - `FastSailEnded(from, to, stages, gold, gems, skipped)`.
- 명령: `SkipFastSail()`(구간 중에만).
- `BattleView.fastSail: FastSailView? {from, to, combo}` — 구간 중일 때만(선택 키).
- 표 `waves.rebirthSkip`: `breakSec` 1.5, `travelSec` 0.3(없으면 지금처럼).

## 연출 (S3)
- 시작 컷인 '⚓ 빠른 항해 돌파!' 금빛 대형(1초), 하늘·바다 황금빛 질주(피버 황금 바다 재사용 + 빠른 물결).
- 보스 등장 → BreakthroughStrike: 선원 포구 일제 발사 줄기 → 거대 폭발·파편·화면 흔들림(설정 따름)·'격파!' 스탬프, combo ×2·×3… 카운터 효과.
- 끝 '스테이지 from → to 돌파!' 웅장한 마무리(금빛 띠·폭죽).

## UI (S4)
- 큰 스테이지 카운터(차르르 올라감) + 연속 격파 수(BattleView.fastSail).
- 끝 요약 창: 돌파한 스테이지 · 얻은 골드·젬 · '더 강해진 당신' 문구.
- 건너뛰기 버튼: 환생 2회차부터(progress.rebirths ≥ 2) 구간 중 표시 → `SkipFastSail`.
- 사운드: 기존 무료 효과음(팡파르·폭발) 조합.

## 수용 기준
1. 구간 시작·끝 이벤트 1번씩, from·to가 빠른 항해 범위와 같다.
2. 구간 스테이지당 시간 ≤ breakSec + travelSec + 여유(테스트: 10스테이지 ≤ 20초).
3. 보상 합 = 보통 보스 격파 보상 합(같은 스테이지들), 요약 이벤트와 일치.
4. 건너뛰기 = 끝까지 돈 것과 같은 보상·스테이지.
5. 표 키 없으면 지금 결과 그대로. 결정론.
