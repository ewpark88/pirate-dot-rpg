# 레인: 화면·메타 UI (ui) — S4 갑판장

- 브랜치: `lane/ui` · 폴더: `D:\Projects\pde-ui` · 진척: `docs/progress/ui.md`
- 소유 경로: `LANES.yaml` → `lanes.ui.paths` (`ui/`, `operator/`, `fixtures/states/`, `parts/ui.*`, `parts/op.*`)
- 설계서: 4.5 다음 목표 막대, 4.6 광고 버튼 규칙, 4.9 피로 금지 규칙, 6.10 운영자 모드

## 목표
탭 4개(항해·배·선원·소환)와 팝업·설정·운영자 패널을 샘플 상태만 보고 만든다. 모든 버튼은 `Command`만 보낸다.

## 기다리지 않고 쓰는 입력
- `fixtures/states/*.json` — `new_player`, `stage37_midgame`, `boss_fight`, `all_crews_mythic` (필요하면 이 레인이 추가)
- 계약의 `Command`/`OperatorCommand`, `BigNum.format()`
- 문구 키: 테이블의 `nameKey`(crew·ship·battle 파트에 이미 있음)

## 할 일 (M2)
1. 상태 구독 구조(Riverpod): 엔진 스냅샷 → 화면. 샘플 상태로 화면 개발
2. 배 탭: 부위 5종 강화 버튼(비용·효과·연타), 배 등급 표시
3. 선원 탭: 40명 목록·등급 프레임·별, 일괄 합치기, 승급 버튼(빨간 점), 증표 교환
4. 소환 탭: 1회·10연, 확률·천장 표시(`rarities.json`에서 직접 읽기), 무료 광고 소환
5. 항해 탭: 상단 다음 목표 막대, 보스 도전, 순풍·보물상자 아이콘, 오프라인 보상 팝업(접속 때 최대 1개)
6. 설정: 언어·자동 강화·자동 보스·흔들림·번쩍임·진동·절전·BGM·효과음, 크레딧(LICENSES.json)
7. 운영자 패널(`operator/`): 설계서 6.10 표의 모든 묶음, 버전 글자 5번 탭으로 열기(`if (kOperator)`)

## 완료 기준
- ko/en 골든(화면마다 영어 1장 이상), 긴 문장 모드에서 잘림 없음
- 탭 4개 고정, 빨간 점은 탭마다 하나, 광고 버튼은 이득을 숫자로
- 2단계(M3~): 튜토리얼, 이탈 방지 장치, 실기기 점검 담당
