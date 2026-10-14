# 스펙: 환생 화면(보물지도) · 보스 약점 표시

- 상태: 승인됨 (2026-10-14, S1) · 레인: ui · 설계서 절: 4.5(환생: 보물지도) · 4.11(보스 약점) · 4.12(항해 탭)

## 목적
- 단순한가: 환생은 항해 탭의 버튼 하나 + 확인 창 하나. 보스 약점은 보는 것만(조작 없음 — 자동 편성이 계열을 섞는다).
- 공정한가: 누르기 전에 잃는 것·얻는 것과 조각 수를 숫자로 보인다(4.5 ‘지금 하면 조각 N개, 다음 조각까지 스테이지 M’).
- 피로가 없는가: 스테이지 40 전에는 버튼 대신 ‘스테이지 40부터’ 안내만, 빨간 점 없음(환생은 선택).

## 규칙
1. 조각 수·다음 조각 스테이지·보너스는 경제 함수(S2 환생 스펙)로만 구한다. 함수가 오기 전엔 `rebirthPreviewProvider`(UI 레인, 기본 null = 카드 숨김)로 화면을 만들고, 이름은 S2 스펙에 맞춘다.
2. 버튼은 `Rebirth` 명령만. 확인 창에서 ‘보물지도 펼치기’를 눌러야 보낸다(되돌릴 수 없으니 한 번 더 확인).
3. 보스 약점은 `regions.json` bosses[id].weakFamilies → 계열 이름(`skills.json` families[].nameKey) 칩. 현재 보스 id는 `battle.enemies`에서 `boss == true`인 적의 `kind`.
4. 문구는 `parts/ui.*.arb`. 보스 이름은 `regions.json` bosses[].nameKey(battle 레인 ARB, main 65f02d3).

## 화면
### ① 항해 탭 — 환생 카드 (지금 빈 탭)
- 위: 해역 이름 + 스테이지(해역 지도는 다음 계획), 최고 스테이지.
- 환생 카드: 지금 지도 조각 n개 · 전체 피해·골드 +X%(조각당 5%, 합산).
  - 가능(이번 회차 스테이지 ≥ 40 — S2 규칙, 사용자 결정 ①): ‘지금 환생하면 조각 +N개’, ‘다음 조각까지 스테이지 M’, **보물지도** 버튼.
  - 불가: ‘스테이지 40부터 환생할 수 있어요’ + 진행 막대(이번 회차 스테이지/40). 버튼 없음.
- 환생하면(환생 횟수 증가) 결과 팝업: 지도 조각 +N · 피해·골드 +X% (상태 차이로 판단).
- 보물지도 → 확인 창: 잃는 것(스테이지·골드·배 강화) / 그대로(선원·도감·젬) / 얻는 것(조각 +N, 보너스 +X%→+Y%), **보물지도 펼치기** → `Rebirth`, 취소.
### ② 보스 약점 (4.11)
- 보스전(`battle.bossActive`)이고 그 보스에 약점 계열이 있으면, HUD 보스 타이머 아래(전장 위 오른쪽)에 ‘약점’ + 계열 칩들(예: 투척 · 공중). 약점이 없는 보스는 표시 없음.

## 수용 기준 — 각각 위젯 테스트
1. Given 미리보기(가능, 조각 +7, 다음까지 3, 현재 0) Then 카드에 ‘+7’·‘3’과 보물지도 버튼.
2. Given 불가(최고 37) Then 버튼 없음, ‘스테이지 40부터’ 문구와 막대 37/40.
3. When 보물지도 → 확인 창의 잃는/그대로/얻는 3줄 Then 펼치기 → `Rebirth` 1개, 취소 → 명령 없음.
4. Given 보스전 + 보스 kind `giant_hermit` Then 약점 칩 ‘Lob’·‘Air’(테이블 순서). `enemy_ship`(약점 없음) Then 표시 없음. 보스전 아님 Then 없음.
5. 영어 골든 2장: 항해 탭 환생 카드(가능), 환생 확인 창. (약점 칩은 기존 보스전 골든 갱신으로)

## 문구 (ko / en) — 키
`uiRebirthTitle`(보물지도 / Treasure Map) · `uiRebirthPieces`(지도 조각 {count}개 · 피해·골드 +{percent} / Map pieces {count} · Damage·Gold +{percent}) ·
`uiRebirthGain`(지금 환생하면 조각 +{count} / Rebirth now: +{count} pieces) · `uiRebirthNext`(다음 조각까지 스테이지 {count} / Next piece in {count} stages) ·
`uiRebirthLocked`(스테이지 {stage}부터 환생할 수 있어요 / Rebirth unlocks at stage {stage}) · `uiRebirthButton`(보물지도 / Treasure Map) ·
`uiRebirthLose`(초기화: 스테이지·골드·배 강화 / Reset: stage, gold, ship upgrades) · `uiRebirthKeep`(그대로: 선원·도감·젬 / Kept: crew, collection, gems) ·
`uiRebirthGainLine`(얻음: 조각 +{count}, 보너스 {from} → {to} / Gain: +{count} pieces, bonus {from} → {to}) · `uiRebirthConfirm`(보물지도 펼치기 / Open the Map) · `uiCancel`(취소 / Cancel) ·
`uiBossWeak`(약점 / Weak) · `uiBestStage`(최고 스테이지 {stage} / Best stage {stage})

## 요청
- S2: 환생 미리보기 함수(현재 조각·이번 획득 조각·다음 조각까지 스테이지·조각당 보너스·해금 스테이지) — 이름·타입은 S2 스펙대로 UI가 맞춘다.
- S1(battle 레인 ARB): 보스 이름 키 12개(`battleBoss…`, regions.json bosses id 순). 오면 약점 칩 앞에 보스 이름.

## 운영자 모드
- 스테이지 이동(40·41·120)으로 환생 카드 확인, 해역 보스 스테이지로 이동해 약점 칩 확인.
