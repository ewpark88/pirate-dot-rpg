# 진척: render (S3)

| 항목 | 내용 |
| --- | --- |
| 현재 계획 | 디자인 개편 ④ HD 전부 전환(사용자 결정 2026-10-17, docs/specs/render-hd-style.md): 기준서·HdKit·굽기 완료 → 대보스 6 완료 → 해역·중간 보스 → 순환 23 → 배(등급·스킨 7). 몬스터 27은 S2·S5 |
| 상태 | v2 승인·main 머지. 선원 바 FleetSlot.rarity 반영. 앱 아이콘 원본(tools/art/icon/)·UI 16px 아이콘 7개 완료 |
| 막힌 것 | 번쩍임 설정 기본값 '약하게'는 설정 담당(S4/S5) · main UI crew_identity·crew_filter 테스트 4건 실패(내 레인 아님) |

## 실기기 측정

| 날짜 | 기기 · Android | 모드 | 10초 요약 6줄 | 판정 |
| --- | --- | --- | --- | --- |
| (대기) | | 부하 장면 | | |

## 세션 로그 (최신이 위)

### 2026-10-18 · S3 · HD v2·숫자 버그·콤보·오프닝
- 버그: 514006ef 피해 숫자 세로 겹침(쌓기 간격을 실제 그린 크기·화면 배율로, 배 피해 0 숨김) + 회귀 top_digits_early_test(dpr 3종). dae0d1c6 HD 보스 맞음 흰빛 간격. 8cc199c0 콤보는 피버에만(fx_map combo.feverOnly).
- 점검 도구: first15_strip_test(STRIP_DIR — 실제 엔진 첫 15분 30초마다 한 장 + log). 최근 결과: 15분에 st23(st22에서 4분 정체 — S2 밸런스).
- HD v2: 대보스 6 전용(림 라이트·이중 광택·표정 3종), 전 보스 표정 공용(HdKit.eye·굽기 기우뚱·별), 표정 시트 4행 연결(EnemyWindup·BossBroken), blob 림 라이트 자동, 배 v2(나무결·밧줄·돛 그림자·등급 장식·선원 돛 위), 보스 처치 HD 터짐(HdBossShatter), 보스 그림 배율 = 엔진 bossScaleOf(boss-scale f79dbe35 머지).
- 오프닝: 3ed689c9 HdOpeningBackdrop 5컷(S4가 main에서 끼움).
- 착탄: 44f0d201 계열별 HD 착탄(HdImpact — 11계열 다른 모양·등급 크기·신화 무지개·겹침 흔들기), 선원 범위·스플래시 연결. 남은 것: 화염·얼음·독(특성) 표식은 S1 답 기다림.
- 이어서: 894e6082 선원 칸 큰 Lv(UI가 BattleGame.crewLevels), 673c8691 남은 보스 v2(이중 광택 자동·보스 그림자 2단), a67562c1 심연의 탑(층 띠·심연 바다 — 출현 거리는 S5 엔진 키 제안), 10e66708 보스전 카메라(배·보스가 전장 58%에 꽉 차게 줌), b81d32ff 피버 가독성(배 위 착탄 반투명·큰 숫자 앞) + crowd_check_test.
- 이어서: 8b9307c0 보스 러시 띠(BOSS RUSH·다음 번호·LAST BOSS!, 탑 띠와 공용), e77900e6 선원 칸 Lv 오른쪽 위(실기기 피해 띠 겹침), f617d0d0 패스·상점 스킨 5종(색 + HdPassDecor).
- e6f576af 부위 마일스톤 펑(PartMilestone — 금빛 빛기둥·×2!·부위 빛, 전엔 효과음만).
- 다음: S1 A줄 일괄 때 render 골든(보스 장면·카메라). 남은 것: 몬스터 v2 디테일, 해역·중간 보스 전용 장식.
- 다음: A줄 오면 render 골든 일괄(대보스 호 자리) → main. 남은 것: 해역·중간 보스 전용 v2 디테일(지금은 공용 표정만), 몬스터 v2 디테일.

### 2026-10-17 밤 2 · S3 · 개편 ③ 연출 마무리 → ④ HD 전환 1단계·대보스 6
- 7ff1ceaa 스킨별 항적·포구 색 + '새 배 스킨!' 변신. 5831f37f 보스 등장/처치 빛기둥·피버 큰 마법진. f545f6f4 render 골든 일괄(sea-v2) — main 머지됨.
- HD: 82d81750 기준서·HdKit 부품·hd_species 목록·HdSheets 굽기(기기 해상도 8장×2방향 toImageSync, 14장 캐시)·TopEnemies HD 경로(회전 없이 좌우 뒤집기). 시범 4종 본 게임. d55cb908 blob(line:) 얇은 선. 대보스 6(ice_slime·sea_croc·kraken_titan·leviathan·monster_whale·poseidon) + 눈 선 두께를 눈 크기에 맞춤 + hd_bosses 골든 — 이번 커밋.
- 이어서: c12ced0a 카드 연출(초반 모든 등급 앞면 공개 + 실제 엔진 5분 회귀 live_cards_test), e209693e HD 보스 24 + 스킨 미리보기 동시 굽기 버그, cf460664 해역 보스 5(생물 보스 29종 끝), 23b2e27e HD 플레이어 배(위에서 본 벡터, 진행 방향 회전). 나눔: S5 = 배 보스 13(main 머지)·몬스터 A, S2 = 몬스터 B.
- slot run 끝(6b048e02, main 6f83f3a2에 머지): render 골든 일괄 + hd_ship 300줄 분리(5cb0960d). test/render 274 초록. --full 남은 실패는 레인 밖(test/proto 4종 S1, test/ui 47건 S4 — HD 배·보스 미리보기).
- 그 사이: e3d2667b·358b7287 쏘기 직전 빛(HdMuzzle 예고 차오름 → 발사 터짐), 59b23253 crew-traits-2 렌더 + EnemyView.rooted, 6b7833b6 HD 미리 굽기·절전 384, 5a48af6a 사운드 점검(새 이벤트 효과음 4·CC0 BGM 3곡 −20 LUFS).
- 다음: S5 EnemyWindup(review/enemy-windup)이 main에 오면 event_director_top에 case 하나(muzzle.windup(id, now, atTicks·tickMs/speed, boss: kind != ranged)) + 일제 사격은 기존 볼리 예고선 그대로.
- 남은 것: crew-traits-2 rooted(wip/render-traits2), 출격 렌더 죽은 코드 정리. 레벨업 반짝이는 S4 카드(OutlineText)로 제안.

### 2026-10-17 밤 · S3 · 모션 v1·배 스킨 v2/v3 → (멈춤: 쿵푸할매 스타일 디자인 개편 최우선)
- 모션 v1: a58cfa0 틱 사이 배 자리·방향 보간·적 방향 보간·기기 픽셀 격자, 449537d 등장 팝인·사망 찌그러짐, 3225c7e 2프레임 넘김 섞기 + 4기기 띠 골든 top_motion_strip_*. 배 위아래 출렁·기울기·돛 은은한 펄럭은 TopShipPainter(now) — 이번 커밋.
- 배 스킨: 3384a4b v2 색·무늬 7종(king·ghostship·frost·lava·fairy·festival·abyss — S1 승인, S2 meta.shipSkins), v3 장식(SkinDecor: 금관·해골 깃발·유령불·쇄빙 날·고드름·철갑 테·굴뚝 불꽃·나비 날개·조개 돛·깃발 줄·풍선·돔·잠망경·물방울).
- 재개 지점(디자인 개편 뒤): ① 스킨별 항적·포구 색 연결(fx_map skinPreview wake·muzzle 값 있음 — TopSeaPainter wake 색·_topMuzzle 색) ② '새 배 스킨!' 0.8초 빛기둥 변신(스킨 id 바뀔 때 loot.reward + 부위 빛) ③ crew-traits-2 rooted 연결(wip/render-traits2) ④ 모션 v1 골든 일괄(slot).

### 2026-10-17 저녁 · S3 · 골든 일괄 갱신·특성·보스 특성 wip·근접 베기 v2
- 3b5c900 main 7a4b32b 머지 + render 골든 일괄 갱신(손맛 v4·피버 v2·특성·C8·보스전 비킴). check --full: test/proto fever_motion 4장만 실패(platform 레인 — S1이 main에서 갱신).
- a3ec94d(lane에 합침) 선원 특성: 연쇄 번개·처형·충전·추적 휨. e1de208 도감 v2 보스 패턴(먹물·삼키기·분열·자폭). 근접 베기 v2(등급별 초승달 궤적·신화 360°). sfx-stuck(S5) 검토 OK.
- wip 브랜치(엔진 들어오면 합침): wip/render-traits2(saw·lobster·bara·sword·davy, rooted 연결 남음), wip/render-boss-traits c87474d(회피·장갑·재생·반사막·분노·호위·가속).
- 다음: 출격(공중 air 5·강습 assault 5) 연출 제거 — 엔진 변경과 함께 근접 베기 v2·일반 탄으로. crew-traits-2·boss-traits 머지 시 wip 합치고 골든.

### 2026-10-17 오후 · S3 · #20·#6·브레이크·첫 일격·#22·손맛 v4·피버 v2·보급·보통 보스 23종
- 60e5be0 #20 빠른 항해 정리(콤보 배너 쉼·일반 숫자 없음·흰 속도선·파도 벽/항적 V자 짧게). 8db78be 카드 묶기(×n·+n). c174653 #6 상자(빛줄기·반사·들썩·반짝 줄). 84e27d1 대보스 움직임. a821bf7 보스 브레이크(충격파·조각·BREAK! 도장·기우뚱·별·노란 게이지). d2ade4c 피버 첫 일격(선장 컷인·금빛 번개 12). 42dd438 #22 카드 앞면 공개(cardFx.minRarity, BattleGame.cardFxMinRarity).
- 85348dd·5089af5 손맛 v4(squash&stretch·파스텔 별/하트·흰 충격파·POP!·치명 별·숫자 overshoot/연쇄 색·코인 튐·5↑ 가장자리) + 피버 v2(전체 금빛·무지개 항적·파편 14·콤보 대형·8자 모션 x·y 항적·꺾임 물보라), 부하 피버 200마리. c0f592f 보급 낙하산 상자. e5f71eb 보통 보스 23종(gen_topdown_rotation_bosses.py). ef85d6c 보스 숨쉬기 공통.
- 다음: slot 받아 손맛 v4·피버 v2 골든 일괄 갱신(+check --full) → 연쇄 번개(pelly, Damage 순서로 튐)·충전 사격·처형·추적 깃털(crew-traits 머지 뒤) → 보스 특성 7종(S2 boss-traits 이벤트 뒤) → 도감 v2 연출(먹물·삼키기·분열·자폭·떼).
- 남은 문제: 손맛 v4로 처치·피격 그리기 호출 증가(150마리 164 → 329, 대부분 squash save/scale) — 실기기 gfxinfo로 확인 필요. 흰 1프레임 원은 번쩍임 설정과 무관(작아서) — 사용자 눈부심 피드백 오면 끔.

### 2026-10-17 · S3 · IdleGate·발열 → 대보스 6종 → 사용자 피드백 #18·#15·#4·#17
- a00ce43 IdleGate 미연결 발견(battleGameProvider가 idle.follow를 안 부름) → 렌더 발열 입력 idle.heat(ThermalLevel.index: 보통↑ 가벼운 그리기·심함↑ 효과음 절반) + 요청서 render-idle-thermal-link(S4 936b67f8 반영).
- 3394004 대보스 6종 도트 sea_croc·monster_whale·ice_slime·leviathan·kraken_titan·poseidon(kraken은 심해 해역 보스와 겹쳐 kraken_titan) — tools/art/gen_topdown_bigbosses.py + td_shade.py(입체 음영·디더·부위 구분선), 88도트 2프레임 + 컷인 초상, fx_map bossLook. sprites_test가 regions bossRotation·wallBoss 그림 유무도 검사. 시안 docs/specs/render-topdown/bigbosses_v1.png.
- e7eb87a 궁극기 버튼·함성 게이지 그림 삭제(rage 안 읽음). ccf4f6a main 머지 뒤 골든 갱신(check --full 통과).
- 2831897 #18 보스 처치 보상 터짐 TopBossLoot(연쇄 폭발·빛줄기·충격파 → 금화 28·젬이 크게 튀어나와 배로 + 금액). 9addd9b·6bd8afb #15 보물상자(ChestOpened: 금빛 기둥·금화 분수)·광고 보상(SaveRequested adReward: 배에서 기둥·고리·별가루). 9aa2b89 #4 콤보 v2(1초 연쇄, 처치마다 '쿵', 단계 색·크기, 10/25/50/100 터짐) + 한 프레임 3마리째부터 연쇄 폭발. f9f89f2 #17 카드 수집(CardGranted, isNew 크게·'NEW CREW!', starter 금빛 후광), TopLabel 분리.
- 다음: #20 빠른 항해 보스 격파 연출 정리(조잡함 줄이기) → #6 보물상자 누르고 싶게 → 피버 첫 일격·BossBroken·보급 '보급!' → 대보스 움직임 보강(2프레임 차이가 작다 — S1) → 보통 보스 23종(S5 초안 id) → 도감 v2 연출.
- 남은 문제: boss-duel(S5) 머지 뒤 보스전 카메라 78% 당김과 배 비킴이 겹치면 선원 줄에 가릴 수 있음(머지되면 확인). TopTexts.newCrew는 S4가 ARB로 채워야 한글.

### 2026-10-16 밤 · S3 · 발열 대책 (사용자 퇴근으로 멈춤)
- 67b9cda 방치 절전(60초 → 30fps·가벼운 연출, 3분 → 어두운 점 화면 12fps)·효과음 초당 예산 14. 6d94b66 절전 문턱 BattleGame.sleepAfterSec. 30fe9e9 방치 원본을 UI로: game.idle.follow(IdleLevel) — 받으면 렌더는 스스로 세지 않는다.
- 남은 할 일(순서): ① S4 IdleGate 연결 확인(sleep → IdleLevel.dim) ② 대보스 6종 도트(boss_sea_croc·boss_monster_whale·boss_ice_slime·boss_leviathan·boss_kraken·boss_poseidon, 탑다운 64~96px + 컷인) ③ 도감 v2 연출(InkCloud·ink/swallow 예고·BossSwallowed·BossSplit·BomberBlast·떼 작게) ④ S5 피버 첫 일격(UltimateCast 피버 직후 — ultimates 연출 다듬기)·BossBroken(쓰러짐·물보라·피해 숫자 크게)·ShipResupplied 보급 축하(부위별 PartUpgraded 재사용 + '보급!' 띠, 문구는 TopTexts/S4) ⑤ 계열 v3 시차 타격(burst·hop·ringSpeed·submerged) ⑥ 사운드 점검 ⑦ 4기기 골든 눈 확인 ⑧ main 머지 뒤 integer_scale.dart·빈 ScenePainter.paint 삭제.
- 남은 문제: check 실패 4건은 main에서도 깨지는 UI crew_identity·crew_filter(S4). 실기기 프레임 수 미측정(폰 화면 꺼짐).

### 2026-10-16 저녁 · S3 · 보스 카메라 → 계열 v3 → 흰 번쩍임 축소
- 7112bff 보스 카메라(줌·당김, worldToDp). db5aa82·92cda5b·f98df27 계열 v3: 출격 초상 비행(CrewSortie)·레이저 빔(beamTicks)·자탄 폭발(BombletBurst), 새 계열 laser·ring·cluster 발사체 모양. db5aa82는 check 실패 상태로 커밋됨(다음 커밋에서 고침).
- 46e19e8 흰 번쩍임 축소(사용자 '눈이 아프다'): 전체 화면 번쩍 → 가장자리 빛 띠(서서히), 피버 바다 0.5초 smoothstep, 적 흰 실루엣은 보스만, 폭발 코어·포구 흰색 제거, 배 피격은 빨간 테두리. 회귀 테스트 top_flash_test(이웃 프레임 밝기 변화 ≤20%, 10% 넘는 변화 초당 ≤3) — 최대 9.2%.
- 다음: 대보스 6종 도트 생성기 → 도감 v2 연출 → 시차 타격. 남은 문제: 레이저·원형·자탄은 실제 기록에 해당 선원이 없어 골든 없음.

### 2026-10-16 오후 · S3 · 질주 v2 → 보스 포탄 → 해일 → 위협 → 강습 → T4-3 2단계 → 꼬리 v2
- e9baca2 피버 질주 v2(흐름 ×8·모션 블러·바위/부표·파도 벽 2배·돛·바람 줄·시작 가속, 회색 전환 없앰). 41705ad 보스 포탄(BossFired, TopShots). 865b3c3 탑다운 해일(TopWaveFx)·궁극기 탑다운 좌표·빠른 강화 반짝.
- 94ffa43 위협(EnemyFired 종류별 탄·EnemyEmerging 물보라). e103218 강습 근접(TopSlash — 무기 그림 없는 강습 5명이 옆모습 갈고리로 안 보였다) + 계열 8종 골든.
- T4-3 2단계: c3e3302(옆모습 테스트·골든 15개 삭제, 공용 테스트 탑다운으로, 이벤트 주입 withShipHit·withBossFire·withFever·withThreat로 엔진 변화에 견디게) · 4828bba(옆모습 paint·전용 파일 6개·옆모습 카메라·절전 캐시 삭제, 부하 장면 탑다운 150마리).
- 5bd62b9 등급 꼬리 v2(테이퍼, 길이 ×2~12, 등급별 색·이중선·코어·별 가루·무지개).
- 남은 문제: integer_scale.dart·빈 ScenePainter.paint(S5 e2bdec1 머지 뒤 삭제), 옆모습 그림 자산 삭제 여부(S1 결정 대기). 75f7632 'wip' 메시지 실수(c3e3302에 설명).
- 다음: 개성 v2(거북 막·번개·북 파동) → 보스 패턴 v2(S5 머지 뒤) → 화물칸 금고(S2 GoldOverflow 뒤).

### 2026-10-16 · S3 · 발사 임팩트·등급 꼬리·황금 바다(6ab39e3) + 피버 질주·녹이기
- 6ab39e3: 포구 섬광(등급 색)·고리·연기, 등급 꼬리(TrailPainter) 탑다운 연결, 빛나는 황금 바다(밝은 금·주황빛 금 반점·빛 줄기).
- 피버 질주(사용자 '배가 빠르게 나아가며 적을 녹이는'): 바다 흐름 ×4·항적 2배·뱃머리 V자 물보라, 속도선 강화, 배 앞으로 기울임·위아래 흔들림, 카메라 6dp 앞. 녹이기: 반지름 R(fx fever.meltRadius 42 — S2 FeverAura 오면 그 값) 빛 원, 안의 적 빨갛게(drawAtlas modulate 묶음)·불씨·연기.
- S4 요청: 탑다운 피버 전장 상자 금빛 테두리 끔(UI 가장자리 빛이 맡음).
- 남은 문제: 카메라 6dp 앞 이동 동안 UI 탭 자리(TopFrame.shipScreen)와 6dp 어긋남 — 황금 물고기 탭에 작게 영향. 뱃머리 V자는 폰에서 확인.
- 다음: T4-3 2단계 → S5 현상금 B3.

### 2026-10-16 · S3 · 피버 연출(사용자 '임펙트가 하나도 없다') + 상선 축소
- top/top_fever.dart(TopFever): 시작 = 배에서 금·주황 충격파 고리 2개(0.65초) + 화면 금빛 번쩍(screen 섞기, 0.35→0.75) + 흔들림. 동안 = 바다 호박색(topSea feverBase·Deep·Shallow — 덮개 섞기는 파랑+금=탁한 초록이라 팔레트 자체를 바꿈), 배 둘레 불꽃 오라, 발사체 굵게(+35%)+불 꼬리(PbFxPainter.fever), 처치 불꽃·코인 2배, 가장자리 속도선(흔들기 끄기·절전이면 없음). 끝 = 1.2초에 걸쳐 원래 색.
- 적 그리기를 top/top_enemies.dart(TopEnemies)로 뺐다(300줄). 보물 상선 그림 0.55배(경로는 S2·S5가 배 밖 40단위 가로 직선으로).
- 골든 top_fever_start_s24·top_fever_mid_s24(실제 기록, 피버 시작 0.25초·3초 뒤).
- 남은 문제: 호박색 바다 위 물속 해파리(반투명)가 분홍빛으로 보임 — 폰에서 사용자 확인.
- 다음: T4-3 2단계 → S5 현상금 B3.

### 2026-10-16 · S3 · 배 충돌 연출 + 상태 아이콘 읽히게
- 사용자 '적들이 배에 부딪히지 않는다': 엔진은 닿는데 눈에 안 보였다. top/top_hits.dart(TopHits) — 때린 적(fromX/fromY에 가장 가까운)이 배 쪽으로 4단위·120ms 돌진, 닿은 선체 가장자리에 물보라·나뭇조각·작은 번쩍, 배 번쩍 110ms(연달아 맞으면 300ms마다 한 번), 배 미세 흔들림(흔들기 설정), 배 피해 숫자 작게(맞은 쪽 위). 엔진 무관.
- 상태 아이콘: top/top_status.dart — 5×5 도트+남색 테두리(별·불꽃·눈송이·깨진 방패), 무리 속 색종이 문제 해결.
- 골든 top_hit_s24(실제 기록 첫 배 피격), top_marks_s24·탑다운 4장.
- 다음: T4-3 2단계(옆모습 삭제) → S5 현상금 B3 연출.

### 2026-10-16 · S3 · 배 사라짐 수정 + 체력 막대 알약형(사용자 지시)
- c039bbd: 시트를 연 뒤 배가 선원 줄 밑에 남던 것(배 높이 따라가기가 장면 시계로만 진행 — 시계가 멈춘 채 다시 그리면 옛 자리). 시계가 안 가면 바로 제자리 + top_sheet_ship_test. 고강화와 무관(S5 오진 정정).
- 체력 막대: paint/hp_pill.dart(HpPill) — 둥근 알약형 높이 6, 남색 테두리, 위 하이라이트·아래 그늘, 10% 눈금, 흰 지연 조각, 왼쪽 도트 아이콘(하트·해골). 색은 딱 끊는 3단계: 40% 미만 노랑·15% 미만 빨강(fx_map shipHp midBelow·lowBelow), 깜빡임은 빨강일 때만. 내 배 + 탑다운 보스(새로, 보스 위). UI에는 체력 막대 없음(S4 확인).
- 골든: hp_pill(견본 100~5%), top_marks_s24(보스 33%), 탑다운 4장, 옆모습 골든(같은 막대를 써서 바뀜 — T4-3 2단계에서 지움).
- 다음: 상태 아이콘 키우기 → T4-3 2단계.

### 2026-10-16 · S3 · T4-3 1단계: 옆모습 화가만 그리던 표시를 탑다운으로
- 탑다운에서 아무것도 안 그려지던 것: 보물상자 그림(UI는 누를 곳·링·금액만), 수중 구역, 적 상태 아이콘·보호막·정예 테두리, 배 회복·강화 빛, 화면 번쩍.
- top/top_marks.dart(TopMarks) 새로: 구역(짙은 소용돌이+밝은 테 — 옆모습 색은 파란 바다에 안 보임), 적 표시(그림 반지름 고리), 상자(새 OWN 그림 td_event_chest, gen_topdown_events), 배 빛, 화면 번쩍.
- 골든 top_marks_s24(상태 직접 켜서 한 화면) + 탑다운 4장 갱신.
- 남은 문제: 상태 아이콘이 3단위 점이라 무리 속에선 색종이처럼 보임 — 읽히는 아이콘으로 키울지 다음에.
- 다음: T4-3 2단계(옆모습 코드·테스트·골든 삭제).

### 2026-10-15 밤 · S3 · 사용자 버그 '몬스터가 다가오다 전부 멈춘다' + 60fps 상한 + 폭발 크기 상한
- 원인: TopScenePainter가 poseCount를 무시하고 player.poses 전체를 그렸다 → 파가 끝나 적이 0이 돼도 지난 파의 적이 마지막 자리에 그대로(다음 파까지 최대 약 2초). 엔진은 정상(S1 측정과 일치).
  라이브 재생(엔진 push 50ms·렌더 60fps, stage 23, 30초) '보이는 적 전부 정지' 프레임: 12.7%·가장 긴 126프레임(2.1초) → 5.2%·가장 긴 9프레임(남는 건 엔진 히트스톱 1~2틱). 회귀 테스트 top_live_freeze_test.
  히트스톱 값(juice crit 40·multiKill4 70)을 줄이면 2.0%까지 내려가지만 선원 균형(balance crews)이 바뀌어 되돌림 — S1·S2 결정 사항.
- 0e62424: 전투 프레임 상한 평소 60(fx_map frameCap.battleFps)·절전 30.
- 탑다운 폭발 그림 지름 상한 30단위(S2 topRadius 34로 폭발이 배를 덮던 것).

### 2026-10-15 · S3 · 배터리·CPU: 화면 밖 컬링·항적 점 묶음·가벼운 폭발
- 탑다운 화면 밖 컬링: 적(drawAtlas 묶음에서 제외)·발사체·이펙트·코인·숫자 — 보이는 전장 + 여유 24(TopScenePainter.visibleWorld).
- 항적: 점마다 drawRect(약 90번) → 알파 4단계 drawRawPoints(재사용 버퍼, 할당 없음).
- 가벼운 폭발: 절전이거나 폭발이 4개 넘으면 연기·파편·불씨를 빼고 번쩍·불덩이·충격파만(PbFxPainter.lite).
- 부하(150마리, 매 틱 6발·처치) 프레임당 그리기: 302 → 164(이미지 146 → 66, 사각형 71 → 9). 넓게 퍼진 장면(화면 밖 많음) 154. 기록 ms는 이 PC에서 0.8~1.6으로 들쭉날쭉해 비교 못 함(실기기 S5 측정으로).
- 피버·폭풍 덮개는 `top/top_overlays.dart`로 분리(300줄).

### 2026-10-15 · S3 · 지루함 해소 3종 연출 (S2 c5193fa 계약)
- `scene/fun_director.dart`: FeverStarted(금빛 번쩍·흔들림·진동·소리), GoldfishCaught(금화 터짐 + 금 숫자 + 그 금액 금화가 배로), BottlePicked(병 자리 반짝), SeaEventStarted·ShipLookChanged 소리. EventDirector default → funEvent.
- TopScenePainter: 이벤트 적(goldfish·sea_serpent·merchant_ship)은 td_event 그림, 피버 중 금화 비(결정론, 절전 ½) + 금빛 테두리(선명 테 + 안쪽 번짐, 맥박), 유리병은 배 오른쪽 앞에서 출렁, 폭풍이면 분위기에 비·어둡게·번개 번쩍(번쩍임 설정 따름).
- fx_map topEvents·events(feverStarted·goldfishCaught·bottlePicked·seaEventStarted 소리 = 기존 효과음). 테스트 top_fun_test. 시안 `docs/specs/render-topdown/fun_events_s24.png`.

### 2026-10-15 · S3 · 사용자 지시: 배 15%로 + 부품 단계 극적 변화(돛 1→4·선체·대포)
- e9f7e1f: 탑다운 배 0.85배(fx_map topShip.scale) — S24 약 60dp, 화면 폭 약 15%.
- `gen_topdown_ships.py` 다시: 돛 단계 = 돛대 수(1→2→3→4, 5단계 앞 삼각돛·금 테·해골), 선체 단계 = 길이 +5%·폭 +3%씩 + 뱃머리 뭉툭→뾰족→쇠 충각→금 선수상 + 갑판(두 색 판자·쇠 띠·청동/금 테·마호가니), 대포 = 한쪽 1→2→2(긴)→3(청동)→3(쌍포)→4+회전 포탑→4 금 용포. 망루 크기·화물 개수도 단계별. 큰 돛대(망루)는 늘 같은 자리라 층이 어긋나지 않음. base 층은 빈 프레임(그림자는 지금 선체 단계).
- 축하: 바뀐 부위 층이 12% 커졌다 돌아오며 흰빛(glowPart). 문구 '돛 +1!'은 S4 ARB(ShipLookChanged).
- 비교 `docs/specs/render-topdown/parts/stages_t{1..4}.png`(부위별 단계 + 처음 vs 최대), `first_vs_max_s24px.png`(S24 실제 크기).
- T4-B 균형은 중간 측정까지(S5에 보냄) — 이어서.

### 2026-10-15 · S3 · 사용자 실기기 긴급: 탑다운 카메라 넓게·HUD 정리·발사체/이펙트 크기
- 카메라 가로 180 → 270단위(= 전장 폭): S24 배 약 70dp(폭의 18%), 전장 270이 다 보여 보스 궤도·정지가 화면 안. 태블릿은 320단위.
- 탑다운 HUD: 캔버스 스테이지 글자·보스 타이머를 그리지 않음(UI 진행 게이지가 대신), 콤보는 보이는 높이 18%로(게이지 아래).
- 발사체 상한: 탑다운이면 배 폭의 1/4(12단위, 높이 +45% 포함). 무기·코인 크기는 탑다운 1단위 dp로(PbFxPainter.unitDp). 이펙트는 옆모습 화면 크기 × 0.7.
- paintTop은 part `paint/scene_painter_top.dart`(extension)로 — scene_painter 300줄 안.
- 비교 `docs/specs/render-topdown/wide_camera_4devices.png`(4기기 + S24 보스).

### 2026-10-15 · S3 · 환생 v2 렌더 준비: 스킨 색 바꾸기·금빛 물결·배 미리보기 위젯
- `render/top/ship_skins.dart`: 탑다운 배 층의 정해진 색(테두리·갑판·판자 틈 / 돛 3색 / 깃발)만 바꾼 사본을 스킨마다 한 번(비동기) 만들어 은행에 `<key>@<skin>`으로. TopShipPainter가 있으면 그것으로. 계약 전 값은 fx_map topShip.skinPreview(coral·royal·shadow·phantom, phantom은 돛 은은한 맥박).
- 보물 바다: TopSeaPainter.gold(=TopScenePainter.goldSea) — 바탕·물결·거품·반짝임을 금빛으로, 반짝임 더 빠르게.
- `render/top/ship_preview.dart` `ShipPreview(tables, tier, look, skin?, skinPalette?, size, glowPart?, glow)` + `ShipPreview.preload` — S4 배 탭·다음 외형·축하 팝업·스킨 고르기용(전장과 같은 그림). 골든 ship_preview.png.
- 계약 제안(S2): BattleView.shipLook에 명예 max 반영 + shipTierLook, shipSkin, treasureSea. 오면 연결.

### 2026-10-15 · S3 · 바다 분위기 탑다운판 (platform-fun-atmosphere)
- `render/top/top_atmosphere.dart`(fx_map atmosphere): 12분 순환 낮·노을·밤·새벽(전환 20초), 유령해 늘 밤·심연 늘 어둡게. 색조·어둡게는 바다·풍경에만 → 적·발사체·숫자는 밤에도 같은 색(픽셀 테스트).
  날씨(시간대마다 굴림, 해역별): 비(수면 동그라미 + 옅은 빗줄), 안개(흐르는 흰 막), 오로라 반사(밤 빙하), 화산재(화산 늘), 밤 수면 별 반짝임. 절전 = 파티클 ½·풍경 멈춤.
  풍경: 시작 20초 뒤부터 40~90초마다 배 앞쪽 옆에서 나타나 바다 흐름과 함께 지나감(동시 2개).
- `tools/art/gen_topdown_landmarks.py` → `assets/fx/td_land_<id>.png` 7종(야자섬·등대·고래·난파선·빙산·화산섬·먼 유령선), 2프레임.
- 운영자·테스트용 `ScenePainter.top.atmosphere.offsetMs`(시간대 미리보기). 테스트 top_atmosphere_test 5개. 시안 `docs/specs/render-topdown/atmosphere_s24.png`.
- 탑다운 배 63% 커밋(2ebab76) 비교 `docs/specs/render-topdown/ship63_s24.png`.

### 2026-10-15 · S3 · T2 탑다운 마무리 1: 숫자 배율·투척 높이·골든 4기기·부하 150마리·침몰/축하
- 숫자: 탑다운은 전장 1단위가 옆모습 1도트보다 커서 숫자를 옆모습 화면 크기로(paintNumbers scale = 옆모습 dot / 탑다운 dot).
- 투척·물수제비·떨어지기: Projectile.flat(탑다운) — 땅 위 자리는 직선, 높이(heightAt)는 크기 +45%·수면 그림자(높을수록 작고 흐림).
- 골든 `test/render/goldens/top_{360x640,s24,411x891,tablet800x1280}.png`(T1 엔진 기록 틱 138, 전체 화면·시트 닫힘).
- 부하 `test/render/perf/top_stress_test.dart`: 150마리 + 매 틱 6발 + 처치. 적을 그림·번쩍임별 drawAtlas로 묶어 프레임당 그리기 446 → 304, 기록 0.81ms(디버그 JIT, 상대값). 키 문자열 캐시(프레임당 할당 없음).
- 탑다운 침몰: 작아지며 어두워지고 거품 → 떠오름(saveLayer는 이 1.8초 동안만). 부품 축하·등급 빛·수리 반짝 위치 = scene.shipCenter(탑다운이면 배).
- 남은 것: 보스 정지 위치(S2 bossStandoff 100 대기), 탑다운 대포 반동(대포가 배 층에 있어 생략 — 필요하면 층 분리), 실기기 fps.

### 2026-10-15 · S3 · T2 BattleGame mode 'top' 연결 (T1 엔진 실제 전투)
- BattleGame: 프레임 mode가 top이면 카메라를 상자 dp로 두고 `ScenePainter.paintTop(canvas, TopFrame)` — 탑다운 카메라(바다·항적·물속 적 → 배(그림자·층·체력 막대) → 물 위·공중 적 → 발사체·폭발·코인·숫자), 덮개·HUD·선원 줄은 옆모습 배치 그대로. 모드가 바뀌면 배치 다시.
- 연출(EventDirector): 탑다운이면 발사 = AttackFired.fromX·fromY(없으면 배 중심), 배 피격 숫자 = 배 위, 코인 = 배로. 보스 코인 비는 `scene/coin_rain.dart`(탑다운은 배 위쪽 폭). `scene/top_view.dart`(isTop·topShip·shipCenter·coinTo). EnemyPose.heading(탑다운 도트 회전).
- 테스트: `test/render/top_recording.dart`(T1 엔진 탑다운 기록) + top_mode_test(발사체 배 근처 출발·코인 배로·적 방향). 시안 `docs/specs/render-topdown/live_4devices.png`.
- 남은 것: 탑다운 숫자 크기(전장 1단위가 옆모습 1도트보다 커서 약 1.5배), 투척 포물선(지금은 화면 위쪽으로 휨 → 높이를 크기·그림자로), 침몰·부품 축하·대포 반동 탑다운판, 보스 정지 위치(S2 bossStandoff 100 대기), 탑다운 골든.

### 2026-10-15 · S3 · T2 위에서 본 적 27·보스 14(문어 다리 포함)
- `tools/art/gen_topdown_enemies.py` → `assets/enemies/td_<kind>.png`(16칸, 작은 변종 12칸, 2프레임): 게·해파리·물고기·장어·갈매기·펭귄·물개·오징어·불가사리·성게·용암거북·해골·유령·수정 물고기. 옆모습 색·특징 그대로.
- `tools/art/gen_topdown_bosses.py` → `assets/bosses/td_<kind>.png`(2프레임): 해적선 6종은 탑다운 배 그리기를 팔레트만 바꿔 앞 돛 문장(해골·번개·눈송이·불꽃·초록 해골·빨간 띠), 생물 8종(소라게·빙산 바다코끼리·번개 가오리·용암 고래·크라켄+다리·유령 제독·잠수함) 새로.
- 스프라이트 키 `td_enemy:<kind>`·`td_boss:<kind>`. 해역별 비교 `docs/specs/render-topdown/regions/<해역>.png`, 전체 `enemies_bosses_all.png`(위 = 탑다운, 아래 = 옆모습).

### 2026-10-15 · S3 · T2 탑다운 렌더러 1단계: 카메라·바다·배 층 (S1 보완: 배 정가운데·바다 깊이)
- `render/top/top_frame.dart`: 배율 k를 폭으로만(화면 가로 약 180단위, 0.02 여유) — 시트를 끌어 상자 높이가 바뀌어도 그대로. 배 화면 자리 = 보이는 전장(상자 위 ~ 선원 줄) 가운데. 선원 줄·버튼은 battleFrameFor 그대로(UI 변경 없음).
- `top_sea_painter.dart`(fx_map topSea): 바탕 + 깊이 얼룩 2색(시차 0.6) + 물결 대시 + 거품 숨쉬기 + 햇빛 반짝임(세 무리 drawRawPoints) + 배 항적(V자 두 줄·고물 소용돌이·뱃머리 물보라). 흐름 = 진행 방향 반대. 무늬는 보이는 영역을 덮는 Path 하나씩(층마다 그리기 1번).
- `top_ship_painter.dart`: td 층 6장(shipLook 단계) + 그림자. `top_scene_painter.dart`: 배 가운데 고정 카메라, 시트를 열면 배 자리가 220ms에 걸쳐 따라감. 스프라이트 키 td:<tierId>:<layer>.
- 테스트 top_frame_test(4기기, 높이 4가지에서 k 그대로·배 가운데). 시안 `docs/specs/render-topdown/renderer_4devices.png`.
- 아직 BattleGame에 붙이지 않음(엔진 T1 오면 mode 'top'에서 이 경로로). 다음: 적 27·보스 13 위에서 본 도트 → 2D 발사체·폭발·숫자·코인·체력 막대.

### 2026-10-15 · S3 · T2 탑다운 첫 산출: 위에서 본 큰 배 t1~t4 × 부품 단계 + S24 장면 시안
- `tools/art/gen_topdown_ships.py` → `assets/ship/td_t<n>_{base,hull,cargo,cannon,sail,crowsnest}.png`(같은 크기 층, 이 순서로 겹침, 뱃머리 위). OWN.
  프레임 t1 56×96 · t2 60×106 · t3/t4 66×118 도트, 선체 폭 34~40(돛 포함 약 50). 화면 180도트(시험판)에서 S24 약 105dp.
  층: 바탕(테두리·엇갈린 판자·승강구·돛대·바우스프릿·고물 선실) / 선체 7(징·쇠 띠·충각·금 테·문장·마호가니) / 화물 7 / 대포 7(옆 포 1~4쌍·청동·강철·뱃머리 포·쌍포·금 용) / 돛 5(위에서 본 활대+부푼 천: 기운 자국·깨끗·빨간 줄·해골·금 테) / 망루 6.
- 시안 `docs/specs/render-topdown/`: ships_tiers_stages.png(4등급 × 7단계), scene_s24_tiers.png, scene_4devices.png(시험판 장면 위에 새 배).
- 남은 것(T2): 렌더러 본체(탑다운 카메라·배 가운데·층 겹침 그리기·절전 반영), 적 27·보스 13 위에서 본 도트, 발사체·폭발·숫자·코인·체력 막대 2D, 환생 명예 외형·스킨 4종(팔레트)·금빛 물결.

### 2026-10-15 · S3 · 전체 화면 전투(bottomInset) + 배 체력 막대·피격·침몰 (사용자 결정·지적)
- `battleFrameFor(box, dpr, {bottomInset})` + `BattleGame.bottomInset`(S4 약속): 도크·시트가 가린 높이만큼 선원 줄·궁극기가 위로, 필드는 배율 그대로 위아래만(보이는 필드가 148보다 낮으면 하늘을 자름). 줄 바탕은 상자 바닥까지(bandFill). 테스트: 닫힘 72dp·시트 50%에서 k 그대로, 배 보임.
- UI 연결값(goldTargetDp·onCoinArrive·bottomInset)은 `battle_game_links.dart`(part, mixin)로.
- 배 체력 막대 `paint/ship_hp_painter.dart`(fx_map shipHp): 늘 보임, 초록→노랑→빨강, 25% 아래 맥박, 피격 시 흰 테두리·흔들림·흰 조각이 늦게 줄어듦, 회복 시 초록 반짝. 배 피격 숫자 DamageKind.ship(빨강).
- 무리전 침몰(ShipDamaged hpRatio 0, 보스전 아님): 기울며 물 아래로(물 닿는 줄에서 잘림) → 반에서 수리 반짝 → 떠오름(1.8초). 보스 실패는 기존 어둡게 + UI 문구(S4).
- 비교 `docs/specs/render-fullscreen/fullscreen_4devices.png`(도크·시트 50%), `ship_hp_sink_s24.png`.
- 사용자 결정으로 다음은 탑다운 전환(T2). 옆모습 작업(분위기·이벤트)은 T2 뒤로.

### 2026-10-15 · S3 · 배 부품 외형 단계 + 대포 레이어 + 배 1.3배 (사용자 지시)
- `tools/art/gen_ship_parts.py` → `assets/ship/part_t<n>_<part>.png`(등급마다 hull 7·sail 5·crowsnest 6·cargo 7 프레임, 배 그림과 같은 크기 덧그림) + `part_cannon.png`(7단계). PB 배 모듈 디자인을 도트로. OWN.
  선체: 쇠 띠 → 가로 띠 → 구리 바닥 → 금 테 → 금 문장 → 마호가니(유령선은 깊은 보라). 돛: 기운 자국 → 깨끗 → 빨간 겹줄 → 해골 → 금 테. 망루: 바구니 → 난간 → 깃발 → 망원경 → 등불 → 금 깃발. 화물: 통 → 상자 → 보물상자 → 금 더미. 대포: 쇠 → 긴 쇠 → 청동 → 띠 → 강철 바퀴 → 쌍포 → 금 용.
- 렌더: `scene/ship_geometry.dart`(배 상자·포구 끝 공용), `paint/ship_parts_painter.dart`(BattleView.shipLook 단계, 0단계 = 1단계 그림). 대포는 cannonScale 1.4배, 포구 끝 기준, 발사 때 반동(recoilMs 180). 발사체·포구 화염이 포구 끝에서 나간다.
- ShipLookChanged: 그 부위 흰빛 맥박(glowMs 1400) + level_up 이펙트 + promote 소리.
- 배 1.3배(정수 물리 픽셀 반올림: S24 1.25, 태블릿 1.33). 비교 `docs/specs/render-ship-parts/ships_4devices.png`.

### 2026-10-15 · S3 · 폭탄이 보이게 + 등급 꼬리 + 40명 발사체 구별 (사용자 직접 지시)
- 1배속 비행: 투척 1.4초, 물수제비 1.25, 수중 1.15, 공중 1.0, 충격 0.9, 직사·관통·강습 0.8초. 틱 단위라 배속(순풍 등)이 오르면 그만큼 빨라진다(테스트). 표시 지연 lookahead 16 → 30틱(1.5초).
- 폭탄 크기: 그림 '내용'(투명 여백 뺀 긴 변) 기준 화면 24dp(태블릿 최소 12도트). fx_map pbFx.weaponContent(36개 실측).
- 등급 꼬리 `paint/trail_painter.dart`(fx_map rarityTrail): 영웅 보라 불꽃 / 전설 금빛 + 별 가루 / 신화 무지개 오로라 + 흰 빛 고리. 동시 발사체 20개 넘으면 꼬리 점 절반.
- 무기 없는 강습 5명: 갈고리 + 밧줄 + 얼굴 배지(`paint/hook_painter.dart`). 40명 표 `docs/specs/render-bombs-v2/weapons_40crews.png` — 모두 다름(gull·octo는 둘 다 검은 폭탄이지만 경로가 다름).
- 화면 밖 목표 발사체 측정 테스트(offscreen_target_test): 옛 데모 기록 13발 — S2 사거리 머지 뒤 라이브 기록으로 0 확인 예정.
- 비교 `docs/specs/render-bombs-v2/sequence_4devices.png`(0.2초 간격 8장).
- 앞선 커밋 1178b55(절전): FrameCap(절전 fps 상한을 실제 프레임에) + 배경 Path 캐시, 프레임당 그리기 482→136(평상시)·567→221(부하).

### 2026-10-15 · S3 · 배 이동 + 6칸 확대·궁극기 둥근 버튼 + 칸 3상태 (사용자 결정·지시)
- 배·뱃머리·포구·코인 목표 +30도트(kShipShiftX): 1.5배 t1(93도트)이 4기기 모두 다 보인다. 엔진 waves.shipX 56 → 86(S2에 정정 전달, 처음 68로 말했던 것 정정).
- 선원 줄은 6칸만: 6칸이 한 줄에 들어가는 가장 큰 정사각(360 약 52, S24 약 58, 411 약 62, 태블릿 72dp, 남으면 가운데). 궁극기는 오른쪽 끝 칸 위 둥근 큰 버튼(56~72dp), 아랫변이 줄 위 여백에 걸침. 보스 도전 48dp는 그 왼쪽.
- 칸 3상태 `scene/slot_states.dart`(slotStateAt·slotUnlockStage, UI 공용): 출전(초상) / 열림(밝은 바탕·하늘 점선·'+' 맥박) / 잠김(어두운 판·자물쇠, '스테이지 N' 글자는 UI). 색은 fx_map slotSkin.
- 레이아웃 골든 장면 stage 14 → 31(3상태가 한 화면에). 비교 `docs/specs/render-slot-states/layout_4devices.png`.
- S4 몫으로 깨지는 것: en_m3_hud·en_hud_boss_fight 골든, '궁극기는 필드 안이 아님' 테스트(사용자 결정으로 뒤집힘).

### 2026-10-15 · S3 · 배 1.5배 + 선원 칸 크게 (사용자 지시 '배를 더 키워라, 초상도 키워라')
- 배: fx_map shipScale 1.5, 필드 배율 k에 맞춰 정수 물리 픽셀로 내림(k=1 골든은 1배). 뱃머리 오른쪽 끝·포구 높이(kShipPivotY 102)를 기준점으로 → 발사 위치·포구 화염·엔진 shipX 그대로, 고물 쪽으로 커진다(폰에서 고물 약 30% 잘림 — S1 판단 대기).
- 선원 줄: 기기 배치는 6칸 + 궁극기 7개가 한 줄에 들어가는 가장 큰 정사각 칸(최대 72dp, 가장자리 6·사이 4·위아래 8dp). 보스 도전 칸은 궁극기 바로 위(줄 밖, bossRect y < bandTop)로. 기본(테스트) 배치는 예전 도트 칸 그대로.
  BattleFrame.slotRectInBand·slotSize·bossAbove, layout kSlotMaxDp 등. battle_frame_test 갱신.
- 비교 `docs/specs/render-ship-portrait/layout_4devices.png`. 레이아웃 골든 4장 갱신. S4 골든 2장(en_m3_hud·en_hud_boss_fight)은 S4가 갱신.

### 2026-10-15 · S3 · 보상 코인 연출 (사용자 지시 '돈이 금색 점처럼 들어와 모르겠다') + 태블릿 줄
- `tools/art/gen_coin.py` → `assets/fx/coin_hd.png`: PB 재화 아이콘 화풍 매끈한 금화 4프레임 회전(96px, 4배 그려 줄임), OWN.
- 처치마다 금화 1개(그 처치 골드를 실음), 크게 튀어 오른 뒤 위로 휘는 곡선(베지에)으로 UI 상단 바 골드 자리까지, 회전·화면 18dp 고정(태블릿 최소 11도트).
  도착 프레임마다 금액 합계를 `CoinFlow.onCoinArrive`로(UI: 아이콘 통통·'+금액'), 소리 coinArrive → sfx coin. 동시 28개 상한, 넘치면 마지막 금화에 더함(합계 보존). 보스 코인 비 30 → 16.
  UI API: `BattleGame.goldTargetDp`·`onCoinArrive` (S4에 전달). 테스트 `coin_test`(금액·목표·도착 1번·상한 합계).
- 태블릿 줄 상한 1.6 → 2.0dp(슬롯 72dp, S1). battle_scene 300줄 → CoinFlow, visibleRight·clampBossX는 BattleFrame으로.
- 비교 `docs/specs/render-coins/sequence_4devices.png`. 골든 5장 갱신. check --full 통과.
- 남은 것: coin 효과음 파일(assets/audio/sfx/coin.ogg)은 S1이 tools/art/audio로 구워 넣어야 소리가 난다.

### 2026-10-15 · S3 · 스킨 r1 선원 줄 (사용자 승인 새 스킨, S4 값)
- 골든 battle_reference·battle_sprites 다시 찍음(98138ff, pubspec PB 등록 반영).
- `SlotSkinPainter`(fx_map slotSkin, dp 값을 줄 도트로 환산): 크림 줄 + 위로 그림자, 칸 = 등급 색(PB cards.json main) 테두리 3dp·반지름 12dp·등급 색 세로 그라데이션·흰 하이라이트·아래 그림자,
  PB 얼굴 초상(portrait:<id>, crew_art)을 둥글게 잘라 넣음, 빈 칸 연한 바탕·회청 테두리(+는 UI), 궁극기 금 그라데이션 통통 버튼(아래 4dp 진한 테두리)·게이지 #FF5A6E·번개.
  그라데이션 셰이더는 칸 자리별 캐시(프레임당 할당 없음). PB 초상이 없으면 도트 칸.
- 골든 8장 갱신(스프라이트 읽는 장면). 비교 `docs/specs/render-skin-r1/crew_row_4devices.png`. check --full: S4 en_hud_boss_fight만 실패(S4 레인에서 이미 다시 찍음, main 대기).

### 2026-10-15 · S3 · 포탄·폭발 퀄리티 (사용자 직접 지시) + 태블릿
- 스펙 `docs/specs/render-bombs.md`. PB 무기 36종·폭발 부품 16장 가져오기(import_pb.py), `PbFxPainter`(무기 회전·꼬리, 폭발 단계 합성), 계열별 flightMs·lookahead 16·범위 계열 한 발, 폭발 합치기·상한.
- 태블릿 800×1280: 검사 기기 4종(battle_frame_test·layout 골든). 선원 줄 도트 ≤1.6dp 상한(kBandDotMaxDp) — 휴대폰 3종은 그대로.
- event_director·battle_scene 300줄 → ProjectileRules·mergeBlast로 나눔.
- 골든 4장 갱신 + layout_tablet 새로(PB 그림 미등록 상태로 찍음 — S1이 pubspec 등록하면 스프라이트 골든 다시 찍어야 함). check --full: S4 en_m3_hud만 실패(대기 중).

### 2026-10-15 · S3 · Pirate Busters 선원 그림 가져오기 (사용자 결정: PB 차용, 유료 도구 0회)
- `tools/art/import_pb.py`: 40명 카드 그림(355×480)·얼굴 초상(@2x) → `assets/crew_art/`, 등급 테두리 5종 back·front + legend_rays·shine·sparkle + cards.json → `assets/ui/cards/`.
  무손실 WebP(원본과 픽셀 같음 확인), 94개 1.2MB, 카드 최대 ~14KB(150KB 한도). LICENSES OWN(출처 PB 경로). `--check` 같음.
- 표정 SVG는 아직 안 가져옴 — Flutter에 SVG 의존이 없어 PNG 부위 합성이 필요(상세 화면 설계 때).
- check --full: S4 골든 en_m3_hud만 실패(v3 프레임 대기 중, S4가 재생성) — 이 변경과 무관.

### 2026-10-15 · S3 · 전장 배율 +1 (사용자 직접 지시, v3)
- battleFrameFor: 필드 k+1(왼쪽 기준, 오른쪽 잘림 — S24 보이는 폭 270), 선원 줄은 이전 배율 그대로(줄 좌표 + bandOrigin·bandScale), 줄 윗변 정수 물리 픽셀.
- 보스 clampBossX(그림·발사체 목표·숫자·불꽃), 궁극기 비·코인 비·타격 목표는 보이는 폭 안. 상자 45%는 S4.
- 테스트: battle_frame_test(3기기 — 필드 k+1·줄 k, 빈 띠 없음, 왼쪽 기준·보이는 폭 250~300, 줄 56dp+, 버튼 48dp+). 골든 layout_* 3장 물리 픽셀로 새로, battle_boss_storm·battle_cutin(보스 x 안쪽으로) 갱신.
- 점검 regions_s24.png(18장면) 다시 찍음, 비교 compare_s24_v3.png·goldens_3devices_v3.png.
- check --full: UI 골든 en_m3_hud(S4)만 실패 — 상자 좌표(toDp)가 새 프레임으로 바뀌어서. S4가 상자 45%와 함께 다시 찍는다.

### 2026-10-15 · S3 · 폭발·포탄 보정 (S1 실기기 지적: 무늬 없는 큰 노란 원)
- 원인: 팩 explosion_aoe 앞 프레임(0~2)이 단색 원. 렌더는 팩 시트를 그대로 쓰고 있었다(플레이스홀더 아님).
- `tools/art/gen_fx.py` → `tools/art/overrides/`(import_pack.py의 수작업 보정 경로): explosion_aoe 64×64×8(같은 크기) — 번쩍 별 →
  울퉁불퉁한 불덩이(흰 심 왼쪽 위·노랑·주황·붉은 테) → 충격파 고리·연기 덩이·불티 → 흩어지는 연기, 외곽선. cannonball 7×7(쇠·반짝임).
  import_pack.py로 assets·LICENSES 반영(출처 '수작업 보정').
- 골든 battle_reference·battle_sprites 갱신. 비교 `docs/specs/render-layout-v2/compare_explosion.png`(시트 전후, S24 3장면 전후, 골든 전후).

### 2026-10-15 · S3 · 1단계 마감 점검 (S24, 6해역 × 보스 등장·궁극기·동시 처치)
- 점검 그림 `docs/specs/render-layout-v2/regions_s24.png`(골든 아님, 스크래치 테스트로 18장). 잘림·배치 깨짐 없음.
- 고침 1: 도트 글리프에 '.'·'T'·소문자 a~z가 없어 '3.4K'가 '3 4K', 10^15부터 'aa' 접미사가 통째로 안 보임 → 글리프 추가(UI 공용),
  테스트 `pixel_glyphs_test`(BigNum.format이 내는 모든 글자, 1~10^2000).
- 고침 2: ult_ghost_charge(심연 궁극기)가 48px 칼날 하나라 거의 안 보임 → 2배·필드 높이로 쓸고 지나가게(fx_map).
- 기존 골든 변화 없음, check --full 통과.

### 2026-10-15 · S3 · 피해 숫자 가독성 (platform E8)
- 테스트 먼저 `damage_numbers_test`(5개) → `DamageNumbers.add(key:)`: 같은 적·같은 종류 250ms 안이면 합치고 다시 튀어 오름(지금 그려지는 높이를 새 기준 — 아래로 떨어져 겹치지 않게),
  겹치면 글자 폭 기준으로 위로 비켜 쌓기 최대 3줄, 넘치면 맨 위 숫자에 합침(종류는 그대로 — 커져서 다시 겹치지 않게). 동시 상한·합계 보존 그대로.
  값은 juice damageNumber.mergeMs·stackRows (render_tables는 300줄 제한이라 장면이 raw에서 읽어 넘긴다).
- 골든 battle_numbers(배 앞 밀집 장면) 새로, battle_aoe·battle_reference 갱신. 비교 `docs/specs/render-layout-v2/compare_numbers.png`·`goldens_numbers_before_after.png`.
- check --full: 렌더 전부 통과, UI 골든 en_m3_hud 1개 실패 — main 머지로 들어온 S4 골든이 v2.1 전(하늘 0.55) 상자 좌표로 찍혀 상자 고리가 14px 위. 이 변경 전 HEAD에서도 같은 실패 → S4 재생성 요청.

### 2026-10-15 · S3 · 음원 생성기 이전 (S1 요청, 여유 있을 때)
- `docs/store/audio-gen/` → `tools/art/audio/`(gen_audio.py·chipsynth.py·test_gen_audio.py 그대로, 미리 듣기 출력은 `tools/art/audio/preview/` 무시). LICENSES.json 음원 19개 출처 경로 갱신.
- 확인: 옛 경로와 새 경로 효과음 wav 42개 바이트 같음, 테스트 7개 통과. 옛 폴더 삭제·docs/store 문서 경로는 main 전용 → S1.

### 2026-10-15 · S3 · art 묶음 6: 유령해 (적·보스 스프라이트 전부 완료)
- gen_enemies: skeleton 13×15(뼈 흰빛·녹슨 칼·걸음), wraith 14×15(두건 천·초록 눈·찢긴 끝 흔들림), ghostjelly(팩 jelly 박하 유령빛), cursegull(gull 초록 + 보라 부리).
- gen_bosses: ghost_ship(찢긴 반투명 잿빛 돛·초록 해골·썩은 선체 — 내 배 t4 청록과 구별), ghost_admiral 56×62(삼각 모자 금 테·해골, 초록 빛 눈구멍, 금 단추 외투·견장, 칼, 반투명 유령 꼬리).
- 실수 잡음: 새 GLOW 상수가 thunder_ray의 GLOW를 덮어 그림이 바뀜 → GHOST_GLOW로 바꾸고 --check로 기존 바이트 확인.
- sprites_test 해역 phantom 추가 → 6해역 모두 플레이스홀더 0. 비교 `docs/specs/render-art-enemies/compare_phantom.png`.

### 2026-10-15 · S3 · art 묶음 5: 심연
- v2.1 승인·머지. gen_enemies: angler 18×12(빛나는 초롱 흔들림, 몸 밝게), squid 17×11(다리 오므림), siphon 17×10(빛나는 청록 구슬 셋 물결), eel 24×10(사인 곡선 굽이침).
- gen_bosses: deep_sub 62×36(노란 잠수함·조종탑·잠망경·둥근 창·프로펠러), kraken 64×56(보라 머리·노란 눈 세로 동공·촉수 6 빨판), kraken_tentacle 12×28.
- 렌더: 수중 색조 세기를 해역별로(`backgrounds.<id>.underwaterAlpha`, 기본 0.45, 심연 0.12) — 어두운 심연에서 모든 적이 수중이라 0.45면 묻혔다. 필터는 값이 바뀔 때만 새로 만든다.
- sprites_test 해역 abyss 추가. 비교 `docs/specs/render-art-enemies/compare_abyss.png`. 기존 골든 변화 없음.

### 2026-10-15 · S3 · 화면 배치 v2.1 (S1 후속)
- HUD 글자 ×2·보스 막대 두껍게, 수평선 아래로(하늘 0.7)·깊은 바다 빛줄기·거품, 궁극기 금 테두리 + 번개. 골든 10장 갱신, 비교 `docs/specs/render-layout-v2/`(compare_s24·goldens_3devices·goldens_v2_to_v21).

### 2026-10-15 · S3 · 화면 배치 v2 (사용자 실기기 피드백, 최우선)
- 묶음 4 승인·main a89cb6a 머지, 브리프 `layout-v2-brief.md`·실기기 캡처 확인. S4와 좌표 약속(`battleFrameFor`) 합의.
- `render/viewport/battle_frame.dart`(layout.dart에서 export): 폭 기준 정수배·필드 가운데·늘어난 위 하늘/아래 깊은 바다·선원 줄 56dp+·슬롯 6칸·궁극기/보스 도전 칸 dp 좌표.
  `BattleGame.onGameResize`가 같은 프레임으로 카메라(zoom = k/dpr, 위치 = 보이는 영역 왼쪽 위)·`scene.layout`.
- 배경 보이는 영역 전체 채움, 캔버스 HUD 골드·함성 게이지 제거 → 스테이지·보스 남은 초·보스 체력, 선원 줄 빈 슬롯 + 궁극기 버튼 그림(선장 초상·게이지).
  fx_map slots/hud 정리(위치 값은 layout.dart 상수로).
- 테스트 `battle_frame_test`(3기기), 골든 `layout_*` 3장 새로 + 기존 7장 갱신. 비교 `docs/specs/render-layout-v2/`. check --full 통과.

### 2026-10-15 · S3 · art 묶음 4: 화산
- 묶음 3 승인·main 머지. 화산 배경(주황 하늘·검붉은 바다)에 맞춰 대비 우선 색.
- gen_enemies: lavacrab(현무암 + 아래 용암 빛), lavacrab_small(작은 게 격자 재사용), starfish 15×15·starfish_small 11×11(다각형 별, 프레임마다 9° 돌림),
  lavaturtle 20×12(현무암 등딱지 용암 금, 머리 밝게), firebird(gull 달아오른 노랑 — 주황 하늘 위 대비). `from_grid(colors=)` 팔레트 덮어쓰기.
- gen_bosses: fire_pirate(불꽃 주홍 돛·그을린 끝·불꽃 문양), lava_whale 64×46(현무암·목 주름·용암 금·빛나는 눈·숨구멍 용암 분수).
- sprites_test 해역 volcano 추가. 비교 `docs/specs/render-art-enemies/compare_volcano.png`.
- 골든 `battle_status.png` 갱신: 장면에 있던 lavacrab이 플레이스홀더 → 스프라이트(149px). 전후 `compare_status_golden.png`. (e72c904는 check 실패를 못 보고 커밋 — 이 커밋으로 통과) 수중 적(불가사리)은 렌더 수중 색조로 어두워짐(팩 적과 같은 규칙).

### 2026-10-15 · S3 · art 묶음 3: 빙하
- 배 t2~t4 승인·main 머지(고물이 화면 밖으로 나가는 건 그대로).
- gen_enemies: icecrab(팩 crab 서리 흰빛 색 바꿈 — 처음 얼음 파랑은 바다에 묻혀 밝게), icecrab_small 11×8, penguin 13×13(뒤뚱), seal 20×11(꼬리 듦), snowgull(gull 색 바꿈).
- gen_bosses: icebreaker(얼음빛 돛·흰 줄·눈꽃·강철 선체·고드름), iceberg_walrus 64×52(빙산 위 바다코끼리, 엄니·눈·목 주름·서리).
- sprites_test 해역 glacier 추가. 비교 `docs/specs/render-art-enemies/compare_glacier.png`.

### 2026-10-15 · S3 · art: 배 등급 t2~t4
- `tools/art/gen_ships.py`(ship_t1 바탕): x=24 무늬 없는 줄을 끼워 길이를 늘리고(t2 +8, t3·t4 +16), 위로 윗돛을 얹는다.
  t2 sloop 70×58(윗돛·지브·깃발 꼬리), t3 warship 78×58(돛대 둘·고물 선실 불빛 창·금 띠·포문 한 줄 더), t4 ghost(t3 모양, 보라 잿빛 선체·반투명 청록 찢긴 돛·초록 빛 창/포문).
  t1의 작은 꼭대기 깃발은 지우고 새 깃발 꼬리. gen_bosses.write_png가 알파(4번째 값)를 받는다(기존 그림 바이트 그대로).
- 렌더: `ShipPainter`가 등급 그림을 t1 상자 오른쪽 아래(뱃머리·물 닿는 줄)에 맞춘다 → 포구 화염·발사 위치가 등급마다 맞음. t3·t4는 고물 약 16px가 화면 왼쪽 밖.
- 테스트: 배 등급 파일 t1~t4 있음, 큰 배 오른쪽 아래 기준(픽셀). 비교 `docs/specs/render-art-enemies/compare_ships.png`(t1~t4 + 해역 4곳 발사 장면).
- main(음원 b8a06f5) 머지, 생성기 5개 --check 모두 같음.

### 2026-10-15 · S3 · art 묶음 2: 폭풍해 + giant_hermit 집게
- gen_bosses.py: raider 코드를 `ship_variant()`로 일반화(raider 바이트 그대로) → storm_pirate(먹구름 돛·노란 줄·번개 문양·바랜 선체).
  thunder_ray 64×47(다각형 가오리·등뼈 융기·날개 번개·빛나는 눈·꼬리 불꽃). giant_hermit 집게 갈라짐 쐐기 3줄.
- 새 `tools/art/gen_enemies.py`: flyingfish 17×10×2(손 격자, 날개 위/펼침), stormgull(팩 gull 색 바꿈, 폭풍 하늘 대비로 밝은 잿빛).
- sprites_test 해역 storm 추가. 비교 `docs/specs/render-art-enemies/compare_storm.png`.
- 발견: 배 등급 t2~t4(sloop 30·warship 80·ghost 150) 스프라이트 없음 → stage 30부터 배가 플레이스홀더 상자. 적보다 먼저 보이는 구멍 — S1에 제안.

### 2026-10-15 · S3 · S4 요청 UI 아이콘 14개
- 묶음 1 승인·main 머지. S4 요청(S1 중계)을 폭풍해 묶음보다 먼저: `gen_ui_icons.py`에 gear·quest·tailwind·flag·ad·farm·lock·rebirth·moon(16) · card_back(32) · check·check_empty(8) · hand·bubble(16).
  칠한 칸 + outlined() 자동 외곽선, 톱니·초승달은 극좌표로. LICENSES OWN. 미리보기 `docs/specs/render-ui-icons-s4.png`(위 같은 배율, 아래 남색 판 ×3).
- 다음: giant_hermit 집게 갈라짐 보완 + 묶음 2 폭풍해(flyingfish·stormgull·storm_pirate·thunder_ray).

### 2026-10-15 · S3 · art 묶음 1: 산호초 보스
- 아이콘 승인·main 828953b 머지, Q1 승인(산호초 보스 먼저).
- `tools/art/gen_bosses.py`(zlib PNG 읽기·쓰기, `--check`): raider_ship = enemy_ship 칸 바꿈(핏빛 돛·검은 줄·찢긴 돛 끝·해골·어두운 선체·깃발 꼬리) 62×48,
  giant_hermit = 나선 소라 + 게 몸·눈자루·큰 집게 64×52(중간 보스보다 크게). LICENSES OWN.
- `sprites_test`: 해역별 적·보스 파일 존재(지금 coral). 비교 이미지 `docs/specs/render-art-enemies/compare_coral.png`.

### 2026-10-15 · S3 · 계약 I + art (앱 아이콘·UI 아이콘·적 계획)
- main 2e976cb(계약 I) 머지 → 선원 바 테두리 = `FleetSlot.rarity`(순번). slots_test는 octo rarity 3 → 전설 색으로 확인, 기준 장면 함대에 baseRarity 순번을 넣어 골든 그대로.
- 앱 아이콘: `tools/art/gen_app_icon.py` → `tools/art/icon/` foreground 54·background 54·monochrome 54·legacy 24·splash 48·store 64, 배경색 #5AA9E6.
  ship_t1 비율로 줄별 칸을 손으로 맞춘 해골 깃발 범선 + 자동 외곽선. `apply_icons.py --dry-run` 통과(경고: legacy 둥근 모서리 투명 — 의도).
  참고: apply_icons.py는 cp949 콘솔에서 경고 출력 때 UnicodeEncodeError → `PYTHONIOENCODING=utf-8`로 돌림(S5에 전달).
- UI 16px: `gen_ui_icons.py`에 coin(금화)·star·part_cannon·part_hull·part_sail·part_crowsnest·part_cargo, 칠한 칸 + `outlined()` 자동 외곽선, LICENSES OWN.
- 적 21종·보스 12종: 스펙 초안 `docs/specs/render-art-enemies.md` — 실루엣 9 + 변형 12, 해역 순(산호초 보스 먼저).

### 2026-10-15 · S3 · 렌더 품질 v2 (S1 우선순위)
- v1 커밋 f6af03e·비교 이미지 450c31e → S1 골든 7장 승인·main 머지, main을 lane/render에 머지.
- 기준 scene3.py 재확인: 범위 피해 개별 숫자는 `show=False` → 우리도 Damage(·Kill) 묶음 뒤 AoeDamageSum이면 합산 숫자만(치명타 따로). 테스트 먼저(battle_scene_test).
- 선원 바 v2: 판 36×31·등급 색 2px 테두리·초상 꽉 채움(잘라냄)·계열 색 4px 표식, 값은 fx_map slots. slots_test(픽셀). 등급은 baseRarity — 계약 요청.
- 코인: 이미 기준 물리(vx ±25, vy −40, 중력 200, 0.35초 뒤 (30,96))와 같음. 안 보였던 건 범위 숫자 겹침 + 처치 직후 프레임이라서 → 숫자 정리·찍는 시점 7틱.
- 골든: battle_reference(무리 scene3 배치 9마리×4)·battle_m3(4.4틱, 번쩍임 끝)·나머지 3장은 선원 바 변경. 비교 이미지 gif 프레임 20.

### 2026-10-14 · S3 · 렌더 품질 v1 (사용자 지시: battle_ship.gif 수준)
- 스펙 `render-quality-v1`(S1 승인) + 계약 H(BattleView wave·rage·gold, main 13cbb0b). 팩 `tools/scene3.py`는 읽기만, gif 프레임은 PIL로 비교용 추출.
- 공용 글리프 `paint/pixel_glyphs.dart` 492bda0(UI도 사용), `PixelText`(글자 바뀔 때만 Picture로 굽기).
- 배경: 하늘 4단·타원 구름(흐름)·바다 3단·물결 대시(움직임), 해역 6종은 같은 구조에 팔레트만. 배 (2,70)+출렁임·포구 화염(투척). 적 발밑 기준·출렁임·y순, 일반 HP 바 제거.
  도트 데미지 숫자·xN COMBO·캔버스 HUD(코인+골드·스테이지-파·함성 게이지)·슬롯 6칸(계열색 테두리). 시트 67ms·lightning 아래 끝 기준·궁극기 해일 2배+화면 번쩍임·코인 튐→(30,96).
  `battle_scene.dart` 300줄 맞추려고 발사체·피격 갱신을 `motion.dart`로.
- 골든: `battle_reference.png`(gif 장면 재현) 새로 + 기존 6장 갱신 — 비교 이미지와 함께 S1 승인 대기.
- art: `tools/art/gen_ui_icons.py` → `assets/ui/` 탭 아이콘 4·젬 3프레임(OWN) d22e591. pubspec 등록은 S1.

### 2026-10-14 · S3 · κ 0.25 + 충격 재조정
- κ 기본 0.5 → 0.25(S1). 충격 사다리 power [0.4993, 0.3726, 0.2219×3] → [0.7275, 0.7037, 0.6343×3](자기 피해 = a·power + k 두 점 맞춤),
  전설·신화 powerScale 반복 조정(turtle 1.397/1.5633, pumpum 1.6166/2.3267, cook 0.7496/0.7429, corey 1.0562/1.5154, lamp 0.7416/0.6431).
  `balance crews` 통과: 최대 편차 6.2%, 조합 상위 1% ×1.076.
- sim 20명×3h: 첫 보스 실패 1.24분 · 첫 소환 4.25분 · 스테이지 10 7.38분 · 옥토 첫 승급 31.48분 — 모두 목표 안.
- 튜토리얼(설계서 4.12, 입력 없이 스테이지 1·2 보스 처치): 실패 — 스테이지 1 보스 30초 뒤 체력 44% 남음(피해 약 1.8배 필요, 일반 등급 ±10% 안 불가).
  `first_minutes_test.dart`에 수용 기준으로 넣고 skip(보스 HP, S2 waves 대기).

### 2026-10-14 · S3 · 첫 3분 화면 점검 (③)
- `first_minutes_test.dart`: 새 게임을 실제 엔진으로 3분(누르지 않음) 라이브 재생, 매 프레임 그림(스프라이트 포함) — 예외 없음.
  이벤트: attackFired·damage·kill·multiKill·aoeSum·skillCast·hitStop·waveCleared·bossSpawned·bossFailed. 최대 숫자 11·이펙트 13(상한 안). 보스 경고 그려짐.
  `RENDER_DUMP=<폴더>`면 장면 PNG(t05s·first_hits·boss_warn·boss_fail·t180s) — 눈으로 확인, 렌더 이상 없음.
- 참고: 3분 동안 stage 1에 머물고 첫 보스는 실패(튜토리얼 실패 연출로 보임 — S1 확인 몫).

### 2026-10-14 · S3 · sim 전설·신화 시점 점검 (②)
- 임시 조사(커밋 안 함): `SimPlayer`(시드 1, 연속 접속)를 1시간씩 12시간 돌리며 함대 선원의 레벨별 단독 점수 ÷ 같은 레벨 40명 중앙값.
  전설(L46~)·신화(L61~)가 들어오는 시점 모두 1.00 — 단 충격(turtle)은 단독 피해만 보면 0.14~0.28.
  실제 점수표(지원 환산 포함)로 레벨 47·54·63을 돌리면 모두 ✓(turtle 1.006~1.013) → 균형표와 sim 레벨은 맞는다.
- 발견: 충격 점수의 약 82%가 배 보호분(κ×막은 배 피해)이고 자기 피해는 중앙값의 15%쯤. sim 함대에 turtle이 처음부터 있어
  진행 속도(피해량)는 균형표 기대보다 느릴 수 있다. L63에서 파트너 증가분이 음수(−527, 밀어내기가 직사 대상을 멀리 보냄).
- 참고(경제): 연속 접속 sim에서 첫 신화 8시간째(L61), 12시간째 신화 5명.

### 2026-10-14 · S3 · 실기기 설치 (사용자 확인용)
- lane/render(main f897484 + 렌더 ad020be) profile 빌드 `--dart-define=OPERATOR=true` → Galaxy S24(SM-S921N, Android 16) 설치·실행 확인(프로세스 살아 있음, FATAL 로그 없음).
  화면: 전장 정수배 확대 + 둘레 여백, 배(ship_t1)·초상 스프라이트, 산호초 배경. 사용자 손맛 확인 대기.

### 2026-10-14 · S3 · 원뿔 수정 뒤 재측정
- main f897484(coneNearPx 16) 머지 → `balance crews` 전체(37.5초): 강습 외 계열 평균 1.00(충격 1.01~1.13), 밖 27칸 중 강습 22·충격 5(75레벨 4, 60레벨 lamp).
  강습 레벨별 평균 15: 6.04, 30: 5.60, 45: 5.44, 60: 3.77, 75: 3.36 — 무리전 A가 중앙값의 6~9배, 보스전 B 1.3~1.4배(45 이하). 전설(60·75)은 선원마다 갈림.
  조합 상위 1% ×2.245(실패, 상위 조합 모두 강습 2명). 결과 표 `plans/active/render-balance-crews-report.md` 갱신. 수치 조정은 S1.

### 2026-10-14 · S3 · 조합 시너지 조사
- 한 일: main 897938c(1차 조정) 머지, balance 테스트 통과. 레벨 45 조합 상위 1% ×1.655 재현. 임시 조사(커밋 안 함)로 조합 안 선원별 피해 ÷ 단독 피해:
  강습(crabby)만 무리전 ×5~7, 충격 선원(cook·turtle 둘 다)과 함께일 때. 보스전은 시너지 없음. 지원 버프와 무관.
- 원인: 배에 닿은 적은 `x = shipX`에 멈춤 → cone 각도 `atan2(|dy|, max(dx,0))`이 90° → 원뿔 밖. 충격이 밀어내면 dx>0이 되어 강습이 다시 맞힘.
  조합 점수는 함대 Damage 합만 쓰므로 이중 계산 아님. 수정 제안(근접 거리 규칙 coneNearPx)을 S1에 전달 — battle 레인.
- 다음 할 일: S1 수정 뒤 `balance crews` 재측정·보고.

### 2026-10-14 · S3 · balance crews 구현
- 한 일: 스펙 승인(Q1 (b) 선체 레벨로 실제 ShipDamaged, Q2 κ 0.5, Q3 시간 보고). 테스트 먼저(`packages/game_cli/test/balance/` 9개) →
  `lib/src/balance/arena.dart`(엔진 한 판, 처치·침몰이면 MeasureError, S_tank 25 배수 거절), `crew_scores.dart`(레벨별 중앙값 ±10%, 지원 환산), `combos.dart`(같은 계열 2명 이하 6명),
  `report.dart`(마크다운), `commands/balance.dart` crews(옵션·JSON·종료 코드 0/1/2).
- 결과(`plans/active/render-balance-crews-report.md`): 실패. 중앙값 대비 계열별 — 투척 1.77(15)→0.62~0.87(75), 수중 1.3~1.4(초중반), 관통 1.17~1.37,
  공중 0.67~0.84, 충격 0.47~0.93(지원 환산 포함), 강습 0.13~0.25(보스전 0: 사거리 40px라 보스가 30초 안에 닿지 않음 — 실제 게임과 같음).
  레벨 60·75부터 같은 계열 안에서도 갈림(전설 능력). 조합 상위 1% ×1.267(한도 1.3) 통과.
- 측정 시간: `--quick` 4.3초, 전체 28.6초.

### 2026-10-14 · S3 · balance crews 스펙 초안
- 한 일: main 8f6bf78 머지(LANES: balance.dart·lib/src/balance/·test/balance/를 render로). 설계서 4.8·운영자 명령·엔진 경로 조사 →
  `docs/specs/render-balance-crews.md` 초안: 단단한 스테이지(2001, 일반 보스)에서 Damage 합, A 무리전 12마리 60초, B 보스 제한 시간 피해 ×(60/제한),
  점수 (A+B)/2, 레벨 15~75 중앙값 ±10%, 지원 환산(파트너 증가분 + κ×배 보호분), 같은 계열 2명 이하 6명 조합 N개 상위 1% ≤ 중앙값×1.3, 마크다운+JSON, 종료 코드.
- 발견: 무적이면 엔진이 `ShipDamaged`를 안 낸다 → 배 보호분 측정 방법을 Q1로 S1에 질문.

### 2026-10-14 · S3 · 최적화 조사
- 한 일: 골든 2장 승인 → 44783d4(머지 해시 S1에 전달). 임시 측정(커밋 안 함): 부하 장면 60초·실제 엔진 120초에서 풀 상한 도달 0%,
  최고 이펙트 34/40·숫자 17/24·코인 40/60. 스프라이트 그리기 평균 71번/프레임이 이미지 약 11장으로 묶임 → drawAtlas 후보(필터 쓰는 적은 따로).
  결과·후보 3개를 `plans/active/render-perf.md`에 기록. 코드 변경은 실기기 측정 뒤.

### 2026-10-14 · S3 · '큰 순간' 연출
- 한 일: render-moments 승인, 계약 G 거절(배 등급은 stage 파생) → 요청서에 결과 기록. `Backdrop`을 `regions.regionAt(stage)`로 바꿔 무한 항해 반복 반영(stage 400 → 폭풍해).
  테스트 먼저(`moments_test.dart` 7개) → `Moments`(해역 보스 = regionAt(stage).regionBoss 첫 등장 컷인 1.2초·세션당 1번, 배 등급 = shipTiers.tierAt(stage)·바뀌면 빛기둥+level_up,
  ShipTierUp과 중복 1번, 해역 이동 해일 sweep), `ShipPainter`(등급 스프라이트 `ship:<tierId>`·플레이스홀더 shipLook·빛기둥), 컷인 띠(StagePainter).
- 검증: `tool\check.bat --full` 통과. 골든 `battle_cutin.png` 새로, `battle_boss_storm.png`는 stage 75 배가 sloop가 되어 갱신(미커밋).

### 2026-10-14 · S3 · 적 상태 표시
- 한 일: render-status 승인·계약 F(main 286c687) → 테스트 먼저(`status_test.dart` 4개, 픽셀 확인) → `StatusPainter`(감속 색조·물방울, 화상 불꽃 깜빡임(번쩍임 끄기면 고정), 취약 화살표,
  기절 별까지 머리 위 한 줄 가운데 정렬), 스프라이트 감속 필터. fx_map `status`. render_tables는 설정 묶음을 캐시 getter로 바꿔 284줄.
- 검증: `tool\check.bat --full` 통과, 렌더 테스트 78개. 골든 `battle_status.png` S1 승인 → 7cb5af9, 계획 done/.
- 추가: main 4d480ff(순풍 중 speed 2) 머지, 라이브 speed 2 소비 테스트 추가(버퍼·지연 정상). '큰 순간' 스펙 `render-moments` + 계약 요청 G(BattleView.shipTierId) 초안.

### 2026-10-14 · S3 · 사운드 연결
- 한 일: 골든 `battle_sprites.png` 승인·커밋(d3c03e1). render-audio 승인·계약 E(AudioPort, main 5b8ef89) → 테스트 먼저(`audio_test.dart` 5개) →
  `SoundDirector`(이벤트→fx_map sfx, 타격음 변형·피치 결정론, 같은 id 40ms·프레임당 6개 상한, 해역 bgm), `Backdrop.bgmFor`, `BattleGame(audio:)`·`audioLog`.
- 검증: `tool\check.bat --full` 통과, 렌더 테스트 74개.
- 남은 문제: 어댑터(adapters/, flame_audio)·pubspec 의존은 S1/플랫폼. 음원은 사람이 고른 뒤.
- 추가: 아트 팩 계획 done/. 전설 능력(main 19aa020)의 감속·화상·취약 표시용 계약 요청 F + `render-status` 스펙 초안.

### 2026-10-14 · S3 · 아트 팩 v0.2 적용
- 한 일: S1 결정(Q1 render가 assets·tools/art 소유, Q2 pubspec은 S1 머지 때). `tools/art/import_pack.py`(zip 이미지·json만 읽음, 크기 검증, overrides 우선,
  LICENSES.json 자동, `--check` 재실행 동일) + 테스트 3개 → 에셋 62개(초상 40·fx 8·적 6·보스선·배·발사체 5·코인) 11f3c8c.
  렌더: `SpriteBank`·`SpriteDraw`(nearest·흰 번쩍임·물속 색조), `HudPainter` 분리, `BattleGame.loadSprites/useSprites/spriteCount` 4d537e1.
- 검증: `tool\check.bat --full` 통과(42.3s), 렌더 테스트 67개, `python -I tools/art/test_import_pack.py` OK.
- 커버리지: 적 27종 중 6, 보스 14 중 1(enemy_ship), 발사체 8 중 5(shock·assault·air 없음), 해역 배경 0/6 — 나머지는 플레이스홀더.
- 추가: main(pubspec assets 7개) 머지 → SpriteBank가 AssetManifest에 있는 것만 읽게 수정(없는 종류 읽기 오류 제거) 0b16bdb.
  부하 장면 그리기 비용(테스트 환경·소프트웨어 래스터, 600프레임): 플레이스홀더 record 0.238ms·raster 0.614ms → 스프라이트 record 0.212ms·raster 0.811ms.
  실제 이미지 골든 `battle_sprites.png` 생성(S1 확인 대기, 미커밋). 사운드 스펙 `render-audio` + 계약 요청 E(AudioPort) 초안.
- 다음 할 일: 골든 승인 → 커밋 → render-audio 승인 후 테스트 먼저.

### 2026-10-14 · S3 · M2 관문 준비 + 아트 팩 스펙
- 한 일: 보스 골든 커밋(7bc4922, storm_pirate·deep_sub 색 밝게). `live_engine_test.dart` — EngineHost(실제 엔진) 30초를 60Hz로 라이브 재생:
  적 등장·처치·버퍼 64틱 미만·fps 60·오버레이 숫자·콘솔 `[perf]` 요약이 live에서도 나옴(ab11e7d). 앱은 `battle_providers.dart`가 `battleFeedProvider`로 연결돼 있음.
  아트 팩 v0.2 스펙 초안 `docs/specs/render-art-pack-v02.md`(에셋 배치·import_pack.py·LICENSES OWN 규칙·SpriteBank·pubspec 요청).
- 남은 문제: `flutter run -d chrome` 눈 확인은 아직(테스트로만). art 경로는 lane/render에서 쓸 수 없음 → Q1.

### 2026-10-14 · S3 · render-regions (해역 배경·보스 연출)
- 한 일: 스펙 승인(S1)·계약 D 수용, 해역 보스·shielded·tier를 규칙 7~10으로 추가. 테스트 먼저(`regions_test.dart` 수용 기준 1~7) →
  fx_map backgrounds·bossEntrance·bossFailed·bossLook·shield·tierColors, juice bossKill.coinRain + 모델·검증,
  `Backdrop`(stage→배경, 1초 색 섞기), `StagePainter`(배경·원경 장식·보스 경고·실패 덮개), 보스 모양(`EnemyLooks.bossOf`), 코인 비.
  `scene_state.dart`로 HitState·SceneStats 분리(300줄).
- 검증: `tool\check.bat --full` 통과(29.9s).
- 추가: 골든 재승인 → d640aad. main(해역 보스) 머지 → 보호막 테두리·깨짐·tier 테두리 2e9ccae, 렌더 테스트 58개.
- 추가: main(16dda02 stage·chest) 머지 → b78d0fe 프레임 stage로 배경, 보물상자(둥둥·가라앉기·흐려짐). 렌더 테스트 62개.
- 추가: 보스 골든 승인(S1) — storm_pirate #8E3B2E·deep_sub #D4AC0D로 밝게(바다와 겹침) 후 커밋, 계획 done/.
- 다음 할 일: live 모드 실기기 확인 준비(PERF_OVERLAY live), art-pack-v02 스펙 초안.

### 2026-10-14 · S3 · render-m3-fx (스킬·궁극기·적 역할 연출)
- 한 일: 스펙 승인(S1)·계약 A·B·C 수용 기록. 테스트 먼저(수용 기준 1~9, 5는 계약 B 대기 skip) →
  fx_map M3 데이터(skillFxScale·screenSkill·shipSkill·ultimates 8종·enemyLook·split·revive·zone)+모델·검증,
  `M3Director`(스킬·화면 스킬 어댑터·궁극기 sweep/rain/strikes/volley·분열/부활 감지·장판 어댑터), `EnemyLooks`(regions.json 원문 role),
  이펙트 지연·이동(`Effect.delayMs/vx`), 장판 풀, 슬롯 스킬 막대·준비 깜빡임, 배 회복·버프. `scene/motion.dart`로 움직임 계산 분리.
- 검증: `tool\check.bat --full` 통과(33.5s), 렌더 테스트 47개 + skip 1.
- 추가: 골든 승인(S1) → 108a680 커밋. main(전투 M3 12abe88, 계약 A·B·C) 머지 → 어댑터 제거, `scope`·`ZoneSpawned`·`stunned`(별 2개 회전) 사용. 골든 그대로 통과.
- 다음 할 일: 해역 배경 6종 플레이스홀더 + 보스 등장·처치 연출 점검(render-regions 스펙).
- 남은 문제: 기존 골든 `battle_aoe.png`가 적 색(역할 표)·스킬 막대 때문에 바뀜 — 갱신 승인 필요.

### 2026-10-14 · S3 · render-perf (실기기 측정 준비)
- 한 일: 스펙 승인(S1)·Q1 결정(정수배는 렌더 뷰포트) 반영, 실기기 측정 절차를 복사 가능한 명령으로 스펙에 기록.
  테스트 먼저(수용 기준 1~7) → `PerfMonitor`(링 버퍼 p50·p95·최대·fps, 10초 콘솔 요약), `stressRecording()`(적 27·0.5초마다 범위 처치·히트스톱·궁극기),
  `BattleGame.loadStress/loadDemo/resumeLive`·`mode`·`perf`, 절전 `PowerSaveCache`(Picture 재사용), `integerScale`로 카메라 정수배 확대,
  측정 스위치 `--dart-define=BATTLE_SCENE=stress|demo`·`PERF_OVERLAY=true`·`POWER_SAVE=true`, 오버레이 `PerfOverlay`.
- 검증: `tool\check.bat --full` 통과(28.8s), 렌더 테스트 34개.
- 다음 할 일: 실기기 측정 결과 받기 → 표 기록 → 넘으면 원인(이펙트·숫자·그리기) 최적화 스펙.
- 남은 문제: `flutter run -d chrome` 눈 확인은 아직 안 함(위젯 테스트로만 확인). 정수배 확대는 물리 픽셀 기준이라 dpr이 소수면 논리 배율이 소수일 수 있다(정상).

### 2026-10-14 · S3 · 전투 기록 재생 구현
- 한 일:
  - 스펙 승인(S1이 사용자 위임을 전달) → 테스트 먼저(수용 기준 1~9·11) 실패 확인 → 구현.
  - 05e1e80 juice·fx_map 확장(계열 8종 발사체, support→shock 별칭, 넉백·숫자·코인·상한·lookahead).
  - fe06750 `RecordingPlayer`(보간·lookahead 2틱·히트스톱 정지·반복 + S1 요청 라이브 push 모드), `BattleScene`+`EventDirector`,
    `Pool`(고정 크기·오래된 것 회수), `DamageNumbers`(넘치면 오래된 둘 합침).
  - 8f10d56 `ScenePainter`(단색 플레이스홀더), `BattleGame(feed:, recording:, …)`, `battleFeedProvider` — S1이 main에 머지, main.dart가 `host.ticks` 연결.
  - 골든: 샘플 기록은 수치가 바뀔 때마다 재생성되므로 테스트 안 고정 기록으로 찍음(스펙과 다름, S1에 보고).
- 검증: `tool\check.bat --full` 통과(34.6s), 렌더 테스트 24개.
- 다음 할 일: 골든 승인 → 커밋 → 계획 `done/`으로 → `docs/specs/render-perf.md` 초안(실기기 fps·이펙트 수 측정, 30fps 절전).
- 남은 문제:
  - home_screen이 아직 `BattleGame()`(데모 기록) — S4가 `feed: ref.read(battleFeedProvider)`로 바꿀 예정.
  - 정수배 nearest 확대 미구현: `withFixedResolution`이 비정수 배율로 맞춘다. 화면 크기 계산을 UI와 정해야 함.
  - 절전 모드는 장면 갱신만 30fps로 줄인다(그리기는 Flame 주기 그대로).
  - 데미지 숫자 폰트는 기본 폰트(Galmuri는 아트·플랫폼 레인 에셋 등록 후). 진동은 `onHaptic` 신호만.
  - Canvas `Rect` 등 그리기 호출의 작은 할당은 남아 있음(게임 객체·컴포넌트 생성은 0).

### 2026-10-14 · S3 · 레인 시작
- 한 일: worktree `D:\Projects\pde-render`(lane/render) 진입, 레인 브리핑·계약·`juice.json`·`fx_map.json`·합성 기록 확인, 스펙+계획 초안.
  main e4edf73 머지 후 스펙을 `docs/specs/render-battle-replay.md`로 분리. S1 답변(히트스톱 프레임, 데모 기록 상수 경로) 반영.
  main 7156ca6(훅 수정)·f664a25(전투 M1) 머지.

## 2026-10-17 (오후) — 실기기 4건·보스 카메라·해역 바다·유령 제독
- 한 일: b1acb918 현상금 포스터 HD 보스 · 126f7f69 요일 던전 띠(MON n + 계열)·그 날 계열 착탄 금 테 · 3dc3290a 평소 40마리 점검(문제 없음) · S5 피버 무리 사방 조이기 머지(54a81b54) · 2083bcf9 HD 해역 바다 디테일(HdSeaDetail) · 3c6bb50a+3948f4cc 보스 카메라 잘림 없게(안전 영역 fx_map topCam S4 공용, 카메라 점 기준, 줌 0.6~1.3, 시험 top_bosscam_fit 4기기+높은 띠) · HdSheets 밀려난 그림 늦게 버리기(죽는 적 연출 단언 실패 버그) · 621eac6b 유령 제독 HD(마지막 도트 보스).
- 다음: A줄 일괄 때 보스 장면 골든(도감·전리품·특성·피버 무리·해역) 다시 굽기, S4 hudTopDp 연결 확인, 몬스터 v2 디테일.
- 남은 문제: 태블릿 실제 띠 높이는 S4가 hudTopDp로 넘겨야 정확(기본 90dp).

## 2026-10-17 (저녁) — 보스 카메라 역동 복원·숫자 따라가기·처치 손맛
- 한 일: d0b6932b 안전 영역 오른쪽 24dp · 371b4398 보스 카메라 역동 복원(역동 줌 + 펀치를 먼저, 안전 영역 벗어나는 프레임만 깎음, 배 화면 높이 이동, 시험 줌 폭 ≥0.3) · 5216ed0d 피해 숫자가 맞은 적을 따라감 + 무리 처치 손맛 크기 비례(연쇄 pop·흔들림·금화 터짐) + 브레이크 슬로 0.2초 · fa0c3466 처치 카툰 연기 구름.
- 다음: A줄 차례 때 보스·피버·해역 장면 골든 일괄, 몬스터 v2 디테일, 해역·중간 보스 장식.
- 남은 문제: 360폰 대보스(크라켄)는 잘림 방지로 줌 0.6~0.8 — 줌인 여지 적음. 태블릿 hudTopDp는 S4 연결 대기.

## 2026-10-17 (밤) — 임팩트·보스전 묶음·배 이동·메모리
- 한 일: f2e06ede 잡몹 찡긋 · ab4ec16d 피버 바다 v2 · eaa2a7b0/5b8e6fae 메모리(굽기 밀도 줌 제외·지난 보스 해제·프레임 기준 해제·dispose·TextPainter dispose·스킨 사본 재사용·진단 memory()·soak 시험) · 9d7fd36e 탑 배 가림(배 맨 위·칼질 8·심연 밝게) · 63550460 공격 임팩트 · 229a6913 TOTAL · 42e4d2d0 보스 피격 반응 · 2aa19b38/f6fc817e MISS/BLOCK·보스 숫자 · 593d0661/5b8e6fae 배 이동 연출·항적 · 10947dcb 카메라 가로 가운데·작은 숫자 생략 · 6296d6a7 로그 영문(check 막힘).
- 다음: S2 BossBarBroken(층 깨짐)·UltimateCast.manual(컷인·폭주 오라) 해시 오면 연출, S5 meminfo 항목별 결과로 누수 추적 계속.
- 남은 문제: 폰 PSS 증가는 렌더 진단(12분 라이브)에선 재현 안 됨 — Graphics/Native 항목별 측정 대기.

## 2026-10-17 (밤 2) — main 막힘 해결·히트스톱 거르기
- 한 일: 8b724e71 — S5 배 순항 머지 뒤 render 시험 3개(배 고정 가정 → stillTables, 심연 기대값), 히트스톱 거르기(HitStopGate 초당 최대 1.5회), 엔진 넉백 켜지면 렌더 일반 넉백 끔, render 골든 일괄. test/render 337·test/ui 703 초록, 빠른 check 통과.
- 다음: S2 BossBarBroken·UltimateCast.manual 연출, S5 meminfo 항목별 결과로 누수 추적.
- 남은 문제: test/ui 골든 10장(crew_detail·design_k1)이 선원 미리보기 배 순항으로 바뀜 — ui 레인 소유라 S4 갱신 또는 S5 미리보기 순항 끔 필요(S1에 알림).

## 2026-10-17 (밤 3) — 필살기 컷인·보스 층·피버 바다
- 한 일: 129fdef7 필살기 컷인(이름·번쩍·수동이면 크게)·3초 폭주 오라·굵은 불 꼬리 · 36ad9e19 보스 체력바 3층(색·x남은 층·유리 조각·1초 비틀) · 피버 바다 금빛 물결·빛기둥(시험·check 진행 중, 미커밋).
- 다음: 피버 바다 커밋, S2 BossBarBroken/bossBars가 오면 렌더 임시 3층을 그 값으로, S4 crewNames 연결 확인.
- 남은 문제: 폰 PSS 누수 원인 미확정(S5 항목별 측정 대기), test/ui 골든 10장(선원 미리보기 순항)은 ui 레인 몫.

## 2026-10-18 (새벽) — 필살기·gfx·대군·질풍
- 한 일: 2b0e3bed/d4672c86 계열별 필살기 11종(어둡게·빛 번짐·개수 2배·흔들림·끝 충격파) · 027f8e62 화면 전체 saveLayer 없앰(gfx 튐) · ff469495 미리보기 HD 캐시 12MB · bc88e56a/a469da1d 대군 붐빔 모드·부하 시험 120/260/390 · 98e72891 수중 착탄 납작한 파문 · 0a0fc53e 2배속 질풍.
- 다음: S2 순환 보스 +3(18종) id 오면 해역별 HD v2 보스 그리기·커밋, S5 폰 gfx·p95 재측정 결과 반영.
- 남은 문제: test/ui 골든 10장(선원 미리보기 순항·저해상)은 ui 레인 몫.

## 2026-10-18 (밤샘) — 순환 보스 v2 18종
- 한 일: S2에 18종 제안표(id·이름·외형·특성) · 산호 c9348777 · 폭풍 1720acdf · 빙하 cb54eb7e · 화산 750e8fa6 · 심연 96ba703e · 유령 60844930. 도트 없는 HD 전용 보스 크기 기준 빌림(TopEnemies._keyFor).
- 다음: S2가 regions.json 순환에 id 넣으면 장면 확인, S5 폰 gfx·p95 측정 결과 반영.
- 남은 문제: 새 보스 컷인 초상(boss:<id> 도트)·도감 칸 그림은 HD 그림 경로 확인 필요(UI/S4).

