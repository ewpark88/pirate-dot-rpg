# 탑다운 전투 전환 (사용자 결정 2026-10-15)

- 근거: 탑다운 시험판(`apps/game/lib/proto/`, PROTO 빌드)을 사용자가 실기기로 해 보고 "탑다운으로 진행" 결정.
- 사용자 요구: **배는 화면 가운데**, 배 크기를 키워 **부품 외형 변화가 한눈에 보이게**. 세로 화면, 전체 화면 전투 + 도크·끌어올리는 시트(이미 결정).
- 원칙: 옆모습 전투는 탑다운이 같은 수준이 될 때까지 그대로 플레이 가능하게 둔다(설정 플래그로 전환, 완료 뒤 옆모습 코드 삭제). 무료(코드 그림·PB 재료), 4기기(태블릿 포함).

## 단계
| 단계 | 내용 | 담당 | 완료 기준 |
| --- | --- | --- | --- |
| T0 | 계약: 2D 전장(필드 크기·배 위치 중심 고정·적 x,y·방향), BattleView 확장(선택 키), 이벤트에 방향/좌표, 모드 플래그 `battle.view = side/top` | S2(위임) + S5 검토 | 계약 테스트·기존 시나리오 통과 |
| T1 | 엔진 2D화: 스폰(사방·무리 습격), 이동(배 쪽으로), 사거리 = 배 중심 반경, 계열 8종 2D 모양(투척 원·관통 직선·직사 단일·충격 고리·강습 부채꼴·수중 장판·공중 낙하·물수제비 튕김), 보스 거리 두기(원 둘레), 결정론 | S5(시험판 작성자) + S2 균형 | 시나리오·sim 지표(7.2) 통과, balance crews ±10% |
| T2 | 렌더: 탑다운 카메라(배 가운데 고정, 바다가 흐름), 배 크게(부품 외형 층 그대로 위에서 본 모습), 적 27·보스 13 위에서 본 도트, 발사체·폭발·숫자·코인·체력 막대 | S3 | 4기기 골든, 60fps 부하(150마리), 부품 단계 차이가 S24에서 한눈에 |
| T3 | UI: 도크·시트와 전체 화면 탑다운 합치기, 선원 줄·궁극기 위치 | S4 | 4기기 골든 |
| T4 | 전환: 기본값을 top으로, 옆모습 제거, 스토어 스크린샷 재굽기, release_smoke — 아래 'T4 세부' | **S5 리드**(S1 지시 2026-10-15) | 실기기 확인(사용자) |

## 바로 하지 않는 것
- 현상금 사냥·바다 이벤트 연출은 T1·T2 뒤 탑다운 기준으로(규칙·계약은 진행 가능).

## T4 세부 (사용자 지시 2026-10-15 "어차피 가로·옆모습 안 쓸 거다, 구버전 호출하지 마라")
- 방식: 단계마다 리뷰 브랜치 `review/topdown-t4*` → 소유 레인 검토(엔진은 S2) → S1 머지. 순서: T4-1 → T4-B → T4-2 → (T4-3 ∥ T4-4) → T4-5.
- 원칙: 옆모습이 남아 있는 동안 '옆모습 = 결과가 바이트 단위로 같음' 검사는 T4-2부터 없앤다. 대신 탑다운 sim(7.2)·balance crews·시나리오가 기준이다.

| 단계 | 담당 | 할 일 | 완료 기준 |
| --- | --- | --- | --- |
| **T4-1 기본 top** ✅ | S5 | `Settings.battleView` 기본 top(키 없는 옛 세이브 = 탑다운), main.dart 임시 줄 제거, sim·시나리오 기본 top. 옆모습 전용 테스트는 side로 고정해 둠(T4-2에서 정리). 탑다운 관통 조준 = 광선에 가장 많이 걸리는 대상 | check --full (review/topdown-t4 bfe4030) |
| **T4-B 탑다운 균형** | S3(balance crews) + S2(sim) | `balance crews --view top`에서 ±10%: 지금 관통 0.42 · 수중 0.70 · 강습 1.22 · 투척 1.15(나머지 OK). skills.json(families power·ladder) 조정, 필요하면 S5에 모양 조정 요청(예: 관통 폭·수중 반경을 탑다운용으로). sim 7.2 탑다운 목표 통과(오프라인 8시간 강화 5 → 1 문제 포함, S2) | `balance crews` 기본을 top으로 바꾸고 check 통과 |
| **T4-2 엔진 옆모습 삭제** | S5(검토 S2) | `SideGeometry`·`spawnWaveSide`의 옆모습 자리(줄 세우기)·targeting.dart 옆모습 eligible/aim/aimMany 삭제(Hit·Volley·spread·attackReach만 남김). `geometryFor`는 늘 TopGeometry. 옆모습 전용 테스트(battle_test 1·battle_m3 10·battle_standoff·battle_reach·chest 옆모습)는 탑다운 판으로 바꾸거나 삭제. `Settings.battleView`·`BattleView.mode`는 옛 세이브·기록을 읽으려고 키만 남기고 값은 무시(늘 top). 운영자 명령·시나리오에서 side 제거 | 엔진에 'side' 분기 0, check --full |
| T4-2b 표 정리 | S2 | waves.json `field`의 옆모습 전용 값(spawnX·visibleRight·laneY·laneJitter·contactGap·boss standoff·slowZone)·chest 옆모습 자리(xMin·xMax) 삭제, `TopFieldDef`를 `field`로 이름 정리 여부 결정. coneNearPx·spawnSpacing은 탑다운이 쓰니 유지 | game_data 검증·check |
| **T4-3 렌더 옆모습 삭제** | S3 | `scene.isTop` 분기의 옆모습 쪽, 옆모습 ScenePainter·stage/backdrop 옆모습 길, `layout.dart`의 옆모습 좌표, `ShipGeometry.cannonTip` 등 옆모습 전용, 옆모습 골든. `render/demo/sample_battle.g.dart`·`fixtures/events`를 탑다운 기록으로 다시 만들기(game_cli fixtures) | render에 옆모습 0, 4기기 골든, 150마리 60fps |
| **T4-4 UI 옆모습 삭제** | S4 | 운영자 패널 전장 방식 토글 삭제(요청서 platform-topdown-operator 폐기), `battle_overlay`·`chest_layer`의 옆모습 좌표, 튜토리얼 손가락 위치 확인, 옆모습 전제 골든 | ui에 옆모습 0, 골든 |
| **T4-5 출시 점검** | S5 | 스토어 스크린샷 재굽기(store_shots 폰·태블릿 7/10), release_smoke, 실기기 QA(사용자 허락 뒤) | 사용자 확인 |

