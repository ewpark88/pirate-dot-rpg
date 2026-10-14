# economy: M1 밸런스 조정 (sim 기반)

- 레인: economy (S2) · 시작 2026-10-14 · 근거: `game_cli sim` 리포트, 설계서 7.2 · 4.3.3
- 전투 테이블(waves·regions·skills)은 S1 담당 — 경제 테이블(ship_parts·growth·rarities·ads·meta)만 여기서 바꾼다.

## 목표
7.2 지표 7개를 범위 안으로. 바꿀 때마다 `sim --players 20 --hours 3`과 `--schedule daily --hours 72` 리포트를 진척 문서에 붙인다.

## 단계
- [ ] 1. 사람 결정: 젬 광고 가치(ads chest altGems 20 vs summonCostGems 30 → 0.67회) — 어느 쪽을 바꿀지
- [ ] 2. 사람 결정: ‘스테이지 40 누적 1.5~3시간(오프라인 포함)’의 접속 일정 정의 (계속 접속 0.53h / 하루 40분 8.5h)
- [ ] 3. 첫 소환 5분 안: 첫 소환 무료(meta.tutorial.firstTenSummonFree) 반영 또는 초반 젬
- [ ] 4. 오프라인 8시간 = 강화 3~8회: 초당 골드 추정식 보정(범위 이득·실제 엔진 대비) 또는 상한
- [ ] 5. 스테이지 10까지 6~12분: 첫 10분 한 파 33초(S1 전투 조정과 함께)
- [ ] 6. `balance crews` 점수표 (계획 9번)

## 검증
- 위 sim 리포트 + check 스모크
