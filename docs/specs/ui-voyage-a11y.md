# 스펙: 항해 탭 보강 · 한국어 확인 · 접근성

- 상태: 승인됨 (2026-10-14, S1 지시) · 레인: ui · 설계서 절: 4.5 · 4.6 · 4.7 · 4.11 · 4.12

## ① 항해 탭 보강 (한 화면에)
- 해역 카드: 해역 이름 · 해역 안 진행 `n/50`(막대) · ‘해역 보스까지 스테이지 m’(해역 보스 스테이지면 ‘해역 보스 스테이지!’) · 해역 보스 이름 + 약점 칩 · ‘다음 해역: 이름’.
  - 값은 `regions.json`(stagesPerRegion, regionAt, bossAt)에서 바로. 계산식은 표 위치 조회뿐.
- 오프라인: ‘오프라인 골드 시간당 ~X · 최대 8시간’ — X는 경제 `offlinePreview(state, tables, savedAt + 1시간).gold`(받을 때와 같은 계산), 최대는 `meta.offline.maxSec`.
- 순풍: ‘순풍 mm:ss ×2’ 또는 ‘순풍 없음’ (`tailwindRemaining`).
- 환생 카드(기존)는 아래에.

## ② 한국어 확인
- 테스트 글꼴(SDK Roboto)에 한글이 없어 한국어 골든은 만들지 않는다(네모로 찍힘). 대신 ko로 360×640·400×800에서 넘침이 없는지 위젯 테스트:
  탭 4개 + 설정 + 퀘스트·출석 시트 + 소환 결과 + 환생 확인 창 + 복귀 팝업 + 튜토리얼 말풍선 + 운영자 패널.
- Galmuri가 앱에 들어오면(art 레인) 한국어 골든 1~2장을 추가한다.

## ③ 접근성
- `androidTapTargetGuideline`(48dp)·`labeledTapTargetGuideline`(눌리는 것에 라벨)을 탭 4개·설정·시트에서 통과.
- 아이콘만 있는 버튼(톱니·퀘스트 아이콘)은 tooltip으로 라벨.

## 수용 기준 — 위젯 테스트
1. stage37: ‘Coral Reef’ · ‘37/50’ · ‘Region boss in 13 stages’ · 해역 보스 이름·약점 칩 · ‘Next: Storm Sea’.
2. 오프라인 시간당 = offlinePreview(savedAt + 1h).gold.format(), ‘up to 8h’.
3. 순풍 1:30 ×2 / 없음.
4. ko 넘침 테스트 위 목록 모두 통과.
5. 탭·설정·시트에서 두 접근성 가이드라인 통과.
6. 항해 탭이 보이는 골든 갱신.
