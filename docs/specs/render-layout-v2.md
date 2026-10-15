# 스펙: 렌더 화면 배치 v2 (render, S3)

- 근거: main `docs/specs/layout-v2-brief.md`(S1, 사용자 실기기 S24 피드백). 상태: 구현·골든, S1 승인 대기. UI(S4)와 좌표 약속 = 아래 함수.

## 좌표 약속 (`render/layout.dart` → `render/viewport/battle_frame.dart`)
`BattleFrame battleFrameFor(Size box, double dpr)` — 렌더 카메라와 UI 버튼이 같은 계산을 쓴다.
- k = floor(폭·dpr / 320), 필드 148 + 선원 줄이 높이에 안 들어가면 줄인다(최소 1). 1도트 = k/dpr dp.
- 선원 줄 높이 B = max(32도트, ceil(56dp·dpr/k)). 남는 높이: 위 55% 하늘, 아래 45% 깊은 바다. 필드 왼쪽 위는 정수 도트.
- dp 사각형: `gameRect`(320×148 필드), `slotBand`(폭 전체), `slotRects`(6칸, x = 왼쪽+6+i·40도트, 36×31 판), `ultimateRect`·`bossRect`(오른쪽 끝, 정사각, 띠 −6도트, 좁으면 줄임), `buttonsRect`, `toDp()`.
- 그림/누르기: 궁극기 버튼 그림(테두리·선장 초상·함성 게이지, 가득 차면 금·흰 깜빡임)은 렌더, 누르기는 UI. 보스 도전 자리는 비움(UI가 그림).

## 렌더 변경
- 배경: 보이는 영역 전체(맨 위 하늘 띠 위로, 마지막 바다 띠 선원 줄까지, 구름·물결 폭 전체 순환, 깊은 바다 물결 줄 추가, 하늘이 높으면 높은 구름).
- 캔버스 HUD: 골드·함성 게이지 제거. 위 가운데 스테이지-파, 그 아래 보스 남은 초(해골 + 숫자, bossActive·bossTicksLeft), 오른쪽 위 보스 체력(보스가 있을 때).
- 선원 줄: 6칸 고정, 빈 칸은 빈 슬롯 테두리. 덮개(보스 실패·경고 테두리·컷인·화면 번쩍임)는 보이는 필드 영역 전체.
- `BattleScene.layout`(기본 `BattleFrame.standard` = 320×180) — 기존 골든은 이 배치.

## 검증
- `battle_frame_test`: S24 384×832 dpr 2.8125 · 360×640 dpr 3 · 411×891 dpr 2.625(상자 = 폭 × 높이 40%) — 빈 띠 없음, 정수 도트, 띠 56dp+, 버튼 48dp+, 슬롯·버튼 안 겹침.
- 골든 `layout_s24/360x640/411x891.png` + 기존 7장 갱신. 비교 `docs/specs/render-layout-v2/`(실기기 캡처 나란히, 3기기, 전후).
