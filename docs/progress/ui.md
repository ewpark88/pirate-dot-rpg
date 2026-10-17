# 진척: ui 레인 (S4)

## 현재 위치
| 항목 | 내용 |
| --- | --- |
| 계획 | 최우선: 쿵푸할매 스타일 디자인 개편 `docs/plans/active/design-kungfu-style.md`(main) ①단계 UI 스킨 — 내가 주 담당 |
| 상태 | lane/ui 5f35b157 — 광고 칩 접기·처음 열림 안내까지, test/ui 670 초록 |
| 다음 | S3 3948f4cc main 반영 → 띠 아래 끝 잰 값 + 8을 battleGame.hudTopDp에 · trialsReady export 오면 UI 어댑터 지우기 |
| 기다리는 것 | S2 trialsReady export · S5 결제 어댑터 |

### 재개 지점: 보스 특성 UI (멈춤 — 개편 뒤 이어서)
- 브랜치 lane/ui, 마지막 커밋 = '보스 특성 UI 1차'. 계약은 이미 main에 있다(BossDef.traits · counterFamilies · regions.json bossTraits).
- 끝난 것: `apps/game/lib/ui/hud/boss_traits.dart`(traitIcon·traitName·bossCounters·traitSummary·BossTraitLine·bossCounterFamiliesProvider·CounterChip), 이름표(boss_intro)·컷인 이름(boss_cutin_name)·약점 띠(boss_weakness: 특성 + 약점 = 표 약점 ∪ 카운터)·항해 탭 해역 보스 줄·편성 후보 줄 '보스 약점' 칩(fleet_sheet). ARB uiTrait*·uiCounterChip. 단위 테스트 boss_traits_test.
- 남은 단계: ① 특성 보스(storm_pirate 등) 이름표·약점 띠 골든 4기기 ko/en(기존 boss_intro 골든은 특성 없는 대보스) ② 편성 칩 위젯 테스트(fleet.counter.<id>) ③ 크루 탭 카드에도 카운터 표시할지 S1 확인 ④ 컷인 줄 실기기 확인(S3 컷인 띠 높이).
- 다시 시작할 첫 파일: `apps/game/test/ui/boss_traits_test.dart`(골든 추가) → `apps/game/lib/ui/hud/boss_traits.dart`.

## 세션 로그 (최신이 위)

### 2026-10-18 · S4 · 보스전 띠 아래 비우기 · test/ui 복구
- 5f35b157 보스전·장면 중 광고 칩 → 오른쪽 24dp 탭(펼침), 처음 열림 안내 guide.scenes·guide.pass + 카드 OnceTip.
- 734c1afa 보스전·장면 모드 중 띠 아래 알약·약점 줄 없앰, 장면 글은 띠 안. 항해 탭 길어져 깨진 시험 → showInSheet. 전장 안전 영역(위 82dp × uiScale, 아래 선원 줄 − 24dp) S3에 전달.
- 교훈: 빠른 check엔 test/ui가 없다 — 화면을 넓게 바꾼 날엔 해시 전에 test/ui 전부.

### 2026-10-18 · S4 · 결제·패스·요일 던전
- 211ac225 상점(iap.json 18종, 가격 = products().price·없으면 숨김, 묶음·첫 구매 ×2·보유 중·구독 n일·월간 젬 받기, 위 막대 버튼, PurchaseGate 토스트, 스타터 1회 팝업 7일) + A줄 골든 일괄.
- c308af23 운영자 '결제(흉내)' 묶음. 4352be2b 항해 패스(카드·두 줄 30칸·모두 받기·스킨 미리보기). 요일 던전(카드·띠·후퇴·결과).
- 남은 문제: 게임 글꼴에 '₩' 없음 → 'n원'으로 바꿔 보임. 패스 스킨 미리보기는 ShipPreview라 렌더의 패스 장식(HdPassDecor)이 안 보일 수 있다(S3 확인).
- 교훈: 운영자 패널 시험의 _tap은 아래로만 굴려 묶음이 늘면 위 버튼을 놓친다 → 맨 위에서 시작.

### 2026-10-17 밤 3 · S4 · 대본 연결·맛보기·재도전 링·배치 확정·승급 잠금·실기기 ①~⑤
- e2333f92 story.json 대본 + S3 오프닝 배경. 81daad4b 맛보기 팝업(ClaimTrial, 끝나면 광고 10분 더/영구). 9102e65c 자동 재도전 링(autoBossTicksLeft).
- bb31d3d4 HUD 배치 확정(떠 있는 띠 + 얇은 도크) — 다른 안·토글 지움. 0d5541e3 승급 '스테이지 45에서 열림'(stageLocked). a1f7f0b5 A줄 골든 일괄.
- d74e7538·0f1c4bd8 실기기: 복귀 창 받은 뒤 '0 · 잘림'(명령 다음 틱) → 본 양 유지·같은 savedAt 한 번·상한 ×3 계산, 맛보기 조용한 45초·한 실행 1개, '+n 넘침' 배지, CrewPortrait 고해상.
- a1d10e99 탑·러시 화면(lib/ui/scene/: 카드 2·전투 띠·후퇴·결과 창·소탕 토스트, SceneGate).
- 실기기: c8e95807 광고 칩 오른쪽 세로 줄·돌발 이벤트 띠 안 아이콘·알약 한 줄, 9f16008f 시트 열림 중 보스 실패 = 토스트, aada0896 복귀 창 0골드면 ×2 숨김, 86e1480c 선원 탭 머리 한 줄(CrewHeader). 95823405 선원 칸 Lv(crewLevels).
- 남은 문제: trialsReady를 UI가 같은 조건으로 따로 둠(export 오면 지움). 얇은 도크라 탭 이름 시험은 화면 낭독 이름으로.
- 교훈: 앱 전체를 띄우는 새 팝업(맛보기)은 다른 시험을 가린다 — 처음부터 끄는 스위치(trialsEnabledProvider)와 '다른 창이 떠 있으면 기다림'을 같이 넣는다. 포맷은 레포 루트에서(dart format) — 앱 폴더에서 하면 다르게 나올 수 있다.

### 2026-10-17 밤 2 · S4 · 손가락 버그·광고 칩·재도전 표시·HUD 배치 안·시나리오·상점 골격
- 4cbc61d7 화물칸 손가락이 계속 뜨던 버그(force: 금고 가득) → 처음 2번만. 손가락 0.9초 눌림 반복 + 금빛 맥박 테두리(GuideGlow), 숫자 덮지 않게, 말풍선이 보스 도전 버튼 피함.
- a8267a5b 광고 칩을 게이지 아래 오른쪽(BuffChips, 44dp·통통 등장), 순풍 남은 시간 막대. 87c1d5ec '이길 수 있어요!' — settings.autoBoss를 엔진이 안 읽는 것 발견(S2로).
- d7221a84 HUD 배치 안 4개(hudLayoutProvider + 운영자 토글 + 4기기 시안 docs/specs/ui-hud-layout.md).
- 10ab2862 시나리오 골격(오프닝 5컷·보스 대화창, FakeStoryScript). fc459fb3 상점 골격(FakeShopCatalog, shopEnabledProvider 꺼 둠). 스토어 샷 4개 고침.
- 남은 문제: 오프닝 첫 컷 그림이 임시 아이콘(S3 그림 필요). 상점·대화는 가짜 데이터 — 계약 오면 바꿈. 배치 안은 사용자가 고르면 나머지 지움.
- 교훈: 되풀이 애니메이션은 시험 하네스 스위치(guideMotionProvider)로 멈춰야 pumpAndSettle이 끝난다. 같은 provider를 하네스와 테스트가 둘 다 덮어쓰면 오류 — 하네스 인자로.

### 2026-10-17 밤 · S4 · 배 스킨 칸 · 환영 카드 가림 · 도감 보상 · 보스 특성 2차 · #50 모션 · #6 상자
- 1ab0538a 배 스킨 칸: 기본·환생 4·새 7종 한 창(미리보기 + 얻는 방법·진행 + 입기/조각 사기, IconCell 격자, SkinUnlockGate 토스트 + 입어 보기). 스킨 버튼 늘 보임.
- baa8c6ee 환영 카드(starter) 순간 시트 닫기 + 가이드 말 2.6초 접기(guideHoldProvider) — S3 c12ced0a.
- db15ea34 도감 수집 보상 '보상 받기'(collectionRewards) · 새 동료 '다음 보상까지'도 같은 기준. 3a288850 보스 특성 2차(약점 칩 글자·편성 칩 넘침·테스트·골든).
- 36c8df3e #50 모션: 토스트 위에서 내려옴, RollingText(배 효과 숫자), 탭 슬라이드 방향·40dp. c9912b53 #6 상자 '톡!'(처음 3번, hints chest.tap1~3).
- 검토: S5 hd-portrait OK, enemy-windup 피해 줄(자리·percentText 수정 요청), S2 k-windows OK.
- 남은 문제: main --full이 proto·render 골든 14개로 빨강(S2 검진·S3 HD 뒤 갱신 빠짐, 내 레인 밖 — S1에 보고). 전투력 롤링은 '숫자만 바로' 결정이라 뺐음(S1 확인 대기).
- 교훈: State의 AnimationController는 initState에서 — late = 지연 생성은 안 쓴 채 dispose될 때 오류. MarkHint는 CommandLog.hints에 따로 모인다.

### 2026-10-17 저녁 · S4 · 수집의 재미 · 피버까지 n마리 · 팝업 크기 · 보스 특성 1차
- 94c51a99 새 동료 카드(CardGranted isNew, 연출 뒤 2.6초 · 역할 배지 임시 어댑터 crewRoleOf · 이렇게 싸워요 · 도감 n/40 · [출전시키기]).
- f1561459 '피버까지 n마리' 14sp(게이지 × feverKillsAt), 80%+ 금빛 — S5 #9 E 대체.
- c73b6ae4 팝업 크기: popupWidth(폰 85%·태블릿 480) · popupInset · showSkinDialog(200ms 커지며 페이드) 12곳. 관련 12파일 골든만 갱신 — --full 필요.
- 보스 특성 UI 1차(위 재개 지점). 검토: S5 swap-compare·crew-preview 머지 OK 회신.
- 교훈: 남이 slot을 쓰는 동안 빠른 check는 커밋 직전 1회만.
- 6d86f128 개편 UI 마무리: 상자 선택·새 동료 PixelDialog, 보스 피해·도감·교체 비교 SubRibbon, 팝업 480dp를 화면 기준(태블릿 UI 배율로 나눔), LEVEL UP! 연출(crew/level_up_fx.dart), S2·S5 창·reward-fx-wire 검토·합침, 보상 터짐 타이머를 창 안 위젯으로(fleet_engine 전체 run 실패 원인), daily 출석 분리. --full 초록.
- 교훈: 창 밖 Timer는 창과 같이 사라지게 위젯 안에 — 아니면 테스트 끝에 'Timer still pending'(전체 run에서만 드러남).
- a557a0d0 k2 일괄: 외곽선 글자 굵게(Skin.outlined 크기 비례 테 + Skin.bold), 리본 입체·SubRibbon, Skin.inset, 버튼 띠 6, IconCell(배 부위 칸 + Lv 배지), OutlineText 11곳(테 층 RichText로 고쳐 find.text 하나), 흰 글자/테 일괄, 게이지 16dp. test/ui 골든 일괄 118장 + --full 초록.
- 교훈: 두 겹 글자 위젯은 테 층을 RichText로 — 아니면 find.text가 2개를 찾아 테스트 대량 실패.
- 개편 ① k1 시안: Skin 토큰(남보라·연보라·외곽선·초록/노랑 입체·Skin.outlined), PixelDialog 리본+X(RibbonHeader·CloseX·showClose), 도크·탭 막대 네모 칸, 위 막대·게이지·HP·토스트 외곽선. PB 키트는 색이 안 맞아 painter. S5 hd-icons 머지.

### 2026-10-17 오후 · S4 · 가이드 v2 · 브레이크 v2 · 모두 강화 · #5 · 피버 v2 UI · 새 화면 점검
- 0a9836e4·44cca20d·d213ab80 보스 브레이크: 궁극기 제거 → 막대 v2(12dp·외곽선·하늘→노랑·⚡칩·반짝·80% 흔들림·쓰러짐 금빛) → 쿨다운(EnemyView.breakCooldown) 회색+자물쇠+시계.
- e27c43c2 가이드 v2(카드·밝은 곳·손가락·튜토리얼 누름 막기·시스템 카드 9+출항·안내 다시 보기). 하네스 guidesEnabledProvider(guides: true만 카드), withGuidesSeen.
- 60de2b09 #1 패배 안내 v2 · 93b4ca4d 도감 진짜 값 + 첫 처치 토스트 · 60384272 설정 번쩍임 3단계 · a8409e9a 절전 1/5/10/20/30분(기본 10).
- f6f7ff9f 첫 무료 10연 잠금 · 91922d4f #22 카드 연출(crewName·운영자 시작 등급) · 모두 강화(bestUpgradePlan) · a65379ff/0decfa19 #5 보스 vs 나(게이지 안 다음 목표 자리) + 피버 v2(남은 시간 막대·FEVER ×n·끝 요약 n마리) · 02a85945 새 화면 4기기×ko·en 점검 40개(넘침 1건 고침).
- 교훈: TutorialSpot처럼 여러 화면에 감싸는 위젯은 Stack fit(passthrough/loose)이 배치를 바꾼다 — 골든 대량 차이로 바로 드러남. 전투 중 안내 카드는 연출('FEVER!')을 가리지 않게 도크 위.
- 남은 문제: 피버 끝 요약은 위쪽 알약 자리(FeverSlot) — S3 끝 연출과 실기기에서 겹침 확인 필요.

### 2026-10-17 · S4 · fever-break UI · 방치/발열 연결 · 패배 안내 v2 · 도감 진짜 값
- 0a9836e4 궁극기 버튼·함성 게이지 제거, 보스 브레이크 막대(상단 게이지 보스 시간 막대 아래 — S1 승인, 보스 그림 반지름을 UI가 몰라 머리 위 대신)·BossBroken 'BREAK!'.
- 936b67f8 battleGameProvider: idleLevelProvider → game.idle.follow(sleep→dim), thermalLevelProvider → game.idle.heat (S3 요청 render-idle-thermal-link).
- 60de2b09 #1 보스 패배 안내 v2: '배를 강화하거나 선원 레벨을 올린 뒤 다시 도전' + [배 강화]·[선원 레벨업](도크 탭 시트) + [보스 도전].
- 795781c4 골든 71장 갱신 — 0a9836e4 때 8장만 갱신해 main check --full이 깨졌음(대화상자 뒤 궁극기 그림). **교훈: 여러 화면에 걸리는 변경은 커밋 전 slot 받아 check --full.**
- f76369ef 가이드 v2 스펙 → S1 승인(결정은 스펙 9절). 93b4ca4d 도감 progress.dex 연결 + DexFirstKill 토스트([도감] → 시트).
- 남은 문제: 렌더 hud_painter가 궁극기 원을 아직 그릴 수 있음(S3). 설정 '절전까지 시간'·'번쩍임 끔/약/강' 화면 연결은 S1 첫 배정 2)인데 재배정 목록에서 빠짐 — 확인 필요.

### 2026-10-15 · S4 · 소환 v2 · 스킨 전면 1차 · 전장 50→55% · 편성 교체 · 태블릿 배율 · 도크+시트
- 0201bfa 소환 연출 v2(PB 카드 착지·기대감·3D 뒤집기·컷인·다시 소환), 스킨 기반(ui/skin), Jua+기호 보충 글꼴(S1 등록).
- 7e21988 스킨 1차: 선원 탭·상세 PB 카드, 팔레트·테마·공용 위젯 스킨화, 대비 4.5:1, SkinButton 넘침 버그.
- b9a6929·22c373e·f6af5a7 전장 50→55%, SkinToast(잠긴 칸·FleetRejected), 선원 칸 3상태 탭(렌더 slot_states 규칙).
- 0511eaf 편성 교체 버그: 실제 엔진 통합 테스트 4개 — 명령·엔진 정상, '안 바뀐 것처럼' 보인 원인(출전 중 선원을 고르면 자리만 바뀜·계열 상한 무안내·상세에 바꾸기 없음)을 고침.
- 7c751de 태블릿 UI 배율(짧은 변 480 기준 최대 1.4, dpr 유지). 19935ff 도크 + 시트(빠른 강화 = previewUpgrade 효율 최대).
- 7f43adb 환생 v2 화면(상점·카드 미리보기·확인 창 보물 바다·상자 팝업·배 스킨·칭호) — rebirthV2Provider 가짜, S2 shopView 머지 뒤 교체. 임시 키 uiShop*/uiSkin*/uiTitle*는 econ* 키로 바꾸며 지운다.
- 9a7fff1 보스 실패 안내(처음 자세히 = progress.bossFails ≤ 1)·파밍 띠. 8ce1865 전투력(fleetPower 굴러 오름·+N)·진행 게이지(파 칸·해골·보스 시간). 94239a5 일괄 강화 알약·운영자 battleView 토글. d8212f8 환생 v2 실제 연결(shopView 등), 상자 = RebirthDone, ContentUnlocked 토스트, 명예 외형.
- b0acf04 코인 도착(goldTargetDp·표시 골드). 49a0d88 스킨 r2 시안. 6004765 전장 위 한 줄(게이지+목표, 전투력은 상단 바). d802329 선원 줄 가림 버그(도크 위 상자 광고 줄 → 위로, 시트 넘침 자름, 4기기 매 프레임 테스트)·ShipPreview 배 탭·축하 팝업·rebirthForecast.
- a6fbdd5 상단 골드·전투력 연출 제거(사용자). ceb19b5 지루함 해소 3종 UI. 832d8c3 T4-4 옆모습 UI 정리(토글 삭제·상자 탑다운 좌표). 스킨 r2: SkinDepth 판·PixelDot 숫자/NEW 알약(선원·퀘스트 수)·SkinButton 광택+금색 5초 빛 줄기+주 버튼 톡(pop ×1.6)·SkinPopIn 창/시트·도크 패널 16dp 밀림·RewardSparkle, canMergeAny 연결(전엔 항상 false였음).
- 주의: 병합 충돌은 레인 밖 파일이면 main 쪽(theirs)으로 — 한 번 'ours'로 풀어 렌더 골든을 옛것으로 남긴 적 있음.
- 출석 칸(daily_sheet): 1~4일 · 5~6일 + 7일 두 칸 폭(dc770d8).
- dc770d8 출석 두 줄·설정 묶음 판·ShipPreview 골든(하네스가 진짜 시계에서 먼저 읽음)·오프라인 창 골든 테마. 4935b23 선원 상세 r2(등급·출전 알약, 계열·스킬·전설 작은 판). fa640d9 현상금 B4 UI(카드·시트·전투 띠·후퇴·결과 창·빨간 점 9장) — bountyProvider 가짜.
- 046eddf: 상자 광고 = 상자 옆 반투명 말풍선, 파밍 = 게이지 꼬리표, 알약 160dp 나란히(현상금 중엔 현상금만), 4기기 '가운데 60% 덮는 띠 0' 테스트. 피버: 큰 FEVER!·가장자리 빛(S3는 자기 테두리를 끔)·원형 게이지·끝 +골드. 출전 선원: 엔진 테스트로 합치기·승급이 fleet를 안 바꿈 확인, 마지막 선원 내리기 금지·4초 되돌리기(엔진 규칙은 S2에 요청). 상단 숫자 = fleetPower.dps.
- dbcee14 현상금 = GameState.bounty·BattleView.bounty·meta.bounty·StartBounty/SweepBounty/RetreatBounty·결과 이벤트(광고 버튼은 ads.json에 장치가 있을 때만). cd92641 궁극기 꼬리표·원형 게이지·탭!·발동 띠, 보스 도전 = 보스 초상 + '보스 도전!'(새로고침 화살표 삭제), 빠른 강화 비용·부족·'+부품 Lv' 떠오름. ea08f74 선원 개성 아이콘 4개·한 줄(crewIdentities 표 — aim 계약 오면 교체). 9a65cbf 테스트 기대값을 표·경제 함수에서.
- 대기(S5 review/crew-identity d2e626b 머지 뒤): legendFor가 전설 미만에도 값(traitScale) → crew_detail 제목 '특징(지금 n%)', LegendDef.extraProjectilesChance·extraChainsChance·noFalloffChance는 'n% 확률로 …'.
- 해결: 시트를 거의 전체로 열면 궁극기 원 겹침 → 22ad269에서 버튼 숨김.
- 남은 문제(실기기 확인): 40장 카드 그림 래스터 비용은 위젯 테스트로 안 잡힘.
- 남은 문제: 환생 '처음 1회' 안내는 실행마다 초기화(UI 저장 키 없음 — S2에 Settings hints 요청 필요).
- 남은 문제: 렌더 골든 3장(main, S3 머지 대기)으로 check --full의 Flutter 단계가 빨강.
- 남은 문제(해결됨): 골든에서 ShipPreview 그림 빈칸(미리 읽기가 테스트 시계에서 안 끝남), 렌더 절전 캐시 확인(S3), 상자 팝업과 소환 결과 창 동시 열림 순서, econ 문구 U+2212 글꼴 없음(S2 요청).
- 주의: 시트 애니메이션은 탭 다음 첫 프레임에 시작 — 테스트는 pump() 뒤 pump(600ms). 하네스는 기본으로 고른 탭의 시트를 연다(openTab).

### 2026-10-15 · S4 · 선원 상세 · 수동 편성 · 전장 45% · 태블릿
- 한 일: a9c732a 선원 상세(`ui/crew/crew_detail.dart`: 큰 초상·이름·등급·레벨/경험치·파워·계열·스킬·전설 능력·승급·출전/내리기, 미보유 실루엣+얻는 방법, 문구 `ui/crew/crew_text.dart`),
  수동 편성(`ui/crew/fleet_sheet.dart`·`ui/state/fleet_providers.dart`: 선원 줄 칸 → 후보 시트(파워순)·빈 칸 +·칸 비우기·가득이면 바꿀 선원, 선원 탭 자동 편성), 전장 상자 45%(S3 k+1과 맞춤).
  a6f1082 계약 명령 SetFleetSlot·AutoFleet·GameState.fleet, 합치기 점 = canMergeAny. 그다음 커밋: 칸 수 = fleetSlots, 첫 틱 전 activeFleet, 선원 탭 점에 emptySlotCount,
  태블릿 800×1280(AGENTS 유동 크기): 글 탭 최대 폭 640, 선원 열 4~8, 창 480·시트 640, devices_test 4기기.
- 남은 문제: 보유 효과(ownedBonusPerLevel)는 테이블에만 있고 코어가 적용하지 않아 상세에 표시하지 않았다(S1·S2에 알림). FleetRejected(같은 계열 상한) 안내는 아직 없다.
- 진행 중: 스킨 r1 시안(`docs/specs/ui-skin-r1.md`, 미커밋) — PB 카드 기준, 태블릿 1장 추가 예정. 다음: 배 탭 배 모습 미리보기(S3 함수 협의).

### 2026-10-15 · S4 · 할 일 빨간 점 · 큰 수 설명 (계획 E5·E11)
- 한 일: `ui/state/badge_providers.dart` — 배(살 수 있는 강화)·선원(승급 가능 또는 합치기)·소환(1회 젬 충분·첫 10연 무료·무료 광고) 탭 점, 일괄 합치기 버튼 점. 경제 함수 결과를 bool로 select(값이 바뀔 때만 다시 그림). 보는 탭엔 점 없음.
  PixelDot 8칸(실기기에서 4칸은 안 보였다), 테스트용 dotKey. 합치기 판정은 `mergeAvailableProvider`(기본 false) — S2 `canMergeAny` main 머지되면 본문 교체.
  큰 수: 설정 ‘도움말’에 K·M·B·T·aa… 한 줄, `text/big_num_text.dart` BigNumText(길게 누르면 전체 자릿수, 10^20 넘으면 m × 10^e) — 상단 바 골드·강화 비용·복귀 골드.
  주의: gen-l10n 인자 순서가 알파벳순(uiNumberScientific(exponent, mantissa)). `check --full` 통과(60.9s).
- 다음 할 일: canMergeAny 연결, 골든 승인, 폰 피드백

### 2026-10-15 · S4 · 화면 배치 v2 (사용자 S24 실기기 피드백, 최우선)
- 근거: main `docs/specs/layout-v2-brief.md`, 실기기 캡처 `docs/specs/layout-v2/device_*.png`. S3와 직접 좌표 약속 → `render/layout.dart` `battleFrameFor`(94ec694, main b2b0157).
- 한 일: `hud/top_bar.dart`(48dp: 골드·젬, 순풍 칩 + 광고 그림 버튼(순풍·파밍 중 함포 지원), 퀘스트·설정 그림 버튼 — `PixelIconButton`: 그림 ≈26dp 정수배, 누르기 48dp).
  전장 = 폭 × 화면 40%, 필드 안 버튼 없음. 궁극기 = ultimateRect 위 투명 버튼(그림·게이지는 렌더), 보스 도전 = bossRect PixelButton(그림만). 보스 초는 캔버스. 상자 탭은 frame.toDp.
  전장 아래 띠: 상자 광고(ChestAdStrip, 상자+광고 준비 때만), 보스 약점 한 줄. 글자: `pixelFontSize(dpr, 14/16)` — 11px 정수배 중 14dp·16dp 이상(S24 15.6/19.6dp).
  선원 4열·짧은 이름 한 줄(`text/crew_name.dart` 임시 규칙 — 짧은 이름 키 요청 중)·레벨/카드 배지. 항해·소환 카드 3장, 소환 버튼 64dp, 확률 = 등급 색 막대. 퀘스트 보상 = 젬 그림 + 숫자.
  요청서 platform-ui-store-shots: 소환 결과 별 줄을 이름 위로, 짧은 이름 한 줄. 테스트 기본 크기 = S24(384×832, dpr 2.8125). `devices_test.dart`: S24·360×640·411×891 × ko/en × 샘플 3 × 탭 4 넘침 없음, 360·411 골든 8장.
  실기기 비교 `docs/specs/ui-layout-v2/compare_*.png`(전장은 테스트 빈 상자). `check --full` 통과(72.2s).
- 짧은 이름: S2 키 crew{Id}Short(main 52cf8b8)로 교체 완료 — 임시 규칙 삭제, table_text_test가 40개 확인.
- 남은 문제: 전장 그림은 실기기에서 확인 필요(S1 설치).
- 다음 할 일: S1 실기기 확인 → 2단계 디자인 퀄리티

### 2026-10-15 · S4 · 창·시트·튜토리얼 도트화
- 한 일: c596c26 승인. `pixel/pixel_dialog.dart`: PixelDialog(도트 프레임 창: 아이콘·제목·내용·버튼 줄), PixelSheet + `showPixelSheet`(투명 바탕 시트 + 도트 프레임), PixelDot(Badge 대신 네모 빨간 점).
  환생 확인·환생 결과·복귀 보상·소환 결과 창 → PixelDialog, TextButton → PixelButton. 퀘스트·출석 시트: ListTile → 도트 줄, Divider → 1칸 줄, 출석 칸 PixelFrame(오늘 = 금색 2칸).
  튜토리얼 말풍선 = 금색 테두리 PixelFrame + bubble 아이콘 + 도트 버튼, 가리키기 강조 = 금색 네모 2칸 + hand. ui/에 Material 모양 위젯 없음(운영자 패널 제외). `check --full` 통과(59.6s).
- 다음 할 일: 골든 승인, S24 실기기 피드백 오면 우선 처리

### 2026-10-15 · S4 · 설정 도트화 · 소환 연출 · Material 감사
- 한 일: 700576a 승인·머지. ① 설정: `pixel/pixel_toggle.dart`(PixelToggle 2상태 스위치, 한 칸 = 도트 2칸 · PixelSegmented · PixelListRow), AppBar 대신 도트 머리줄(뒤로 버튼).
  ② 소환 결과: 초상 정수배, 등급 순번별 등장 연출(4단계로 끊는 흰 번쩍임, 길이 200+120×순번 ms, 설정 번쩍임 끄면 없음), 전설·신화는 테두리 깜빡임 3번 뒤 바깥 1칸 빛 테두리. 카드 비율 0.45(360 한국어 넘침).
  ③ 감사(시트·창·팝업·튜토리얼·운영자 제외): NavigationBar → `PixelTabBar`(탭 키 `tab.<i>`, 테스트 전부 키로), 약점 Chip → PixelFrame 칩, 상자 CircularProgressIndicator → `PixelRing`, 항해 탭 ListTile → 아이콘 줄.
  남긴 것: Tooltip(길게 누를 때만, 접근성), 초상 대체 사람 아이콘. `check --full` 통과(87.9s).
- 다음 할 일: 골든 승인. 제외했던 시트·창(퀘스트 시트·환생·복귀·소환 결과 AlertDialog·튜토리얼 말풍선) 도트화는 S1 지시 대기.

### 2026-10-15 · S4 · 다듬기 (S1 우선순위 1~4)
- 한 일: d141e30 승인·머지. 목표 막대 = 전장 바로 아래 도트 띠(깃발·PixelBar). 승급 = 카드 초상 오른쪽 아래 작은 도트 버튼(PixelButton `compact`: 그림은 작게, 누르는 영역 48dp), 빨간 점은 도트 네모.
  버튼 명암: 주 버튼 테두리·그늘 actionDark, 밝은 줄 actionLight, 그늘 2칸(PixelFrame `shadeDots`). 도감: 한 줄(수·공격력) + 막대(전체 진척)·다음 보너스까지.
  S3 아이콘 14종 머지(5662000) → `ui/`의 Material 아이콘 전부 교체(초상 없을 때 사람 아이콘만 남김). `crew_card.dart` 분리(300줄 규칙). `check --full` 통과.
- 다음 할 일: 골든 승인. 소환 결과 카드 초상이 24px로 작다 → 정수배 키우기

### 2026-10-15 · S4 · 도트 UI v2 → HUD 걷어내기·배 탭 줄·platform 요청서
- 한 일: v1 커밋 12e2b20(골든 12장 승인). v2 e44f79a(승인): 선원 카드 정사각 초상(등급 색 2칸 테두리), 미보유 실루엣, 버튼 밝은 줄/그늘/그림자 1칸, S3 탭·젬 아이콘.
  **원인 기록**: Image 기본값 BoxFit.scaleDown이라 v1 초상이 32px보다 커지지 않았다 → CrewPortrait에 BoxFit.fill.
  2b5bb59(승인) platform 요청서: `ui/state/platform_providers.dart`(notifierProvider·saveFailureProvider), 운영자 '플랫폼' 그룹, HUD 위 저장 실패 띠.
  3e5f72f 설정 '알림' 토글(세이브 v4). 6599b85 Material HUD 삭제(`hud_bar.dart`) → `hud/battle_overlay.dart`: 논리 좌표 × 배율로 캔버스 HUD(y 6~12) 아래에
  퀘스트·설정·순풍(왼쪽 위), 보스 타이머(가운데), 보스 도전·약점(오른쪽 위), 궁극기(슬롯 줄 위 오른쪽). 운영자 5번 탭 = 캔버스 스테이지 글자 자리.
  전장 높이 = 폭 × 180/320(최대 화면 절반). 젬은 소환 탭 위. 진행 막대 4개를 `PixelBar`로. 골든 테스트가 그림을 미리 디코드(precacheImages)하게.
  dc37585 배 탭: 부위 아이콘·여백 +2칸·버튼 폭 100. 금화·별 S3 그림(별은 16px라 1개 + 개수), `pixel_icons.dart` 삭제. `check --full` 통과(89s).
- 주의: failures/*.png 커밋했던 실수(S1이 gitignore) — add 전에 status 확인. PowerShell Set-Content는 한글을 깨뜨린다 → 파일 수정은 sed/python.
- 다음 할 일: 골든 11장 승인 → S3 글리프 숫자, 목표 막대 위치(전장 위 캔버스로 옮길지) S1과 상의

### 2026-10-14 · S4 · 도트 UI 품질 v1 (사용자 최우선)
- 한 일: 579dc2e(항해 탭 보강)·de99589(스펙) 커밋. `ui/pixel/`: 팔레트(scene3.py 값), 도트 한 칸 = 실제 픽셀 정수배(k = floor(물리 폭/320)),
  9-slice 도트 프레임(그림 파일 없이 CustomPainter: 윤곽·테두리·하이라이트, 모서리 깎기), 도트 버튼(48dp, 눌림 1칸, 잉크·그림자 없음),
  테마(남색, 네모, Galmuri11 — 글자 크기 = 11 × 도트 한 칸, 화면 픽셀로 11의 정수배), 임시 도트 아이콘(탭 4개·코인·젬·별).
  배·선원·소환·항해 탭과 시트·창·광고·보스 도전 버튼을 도트 프레임/버튼으로. 미뤄 둔 접근성(48dp·라벨) 점검 통과.
  비교 PNG `docs/specs/ui-quality-v1/compare_*.png` — 기준 gif 프레임과 같은 배율(×2)로 나란히. `check --full` 통과(64.1s, 위젯 179개).
- 남은 차이(정직하게): 위쪽 HUD는 아직 Material 막대(S3 캔버스 HUD 오면 걷어냄), 선원 카드가 세로로 길고 미보유 카드가 너무 흐림, 아이콘은 임시.
- 다음 할 일: 골든 승인 → 커밋 → S3 HUD 전환, 카드 다듬기

### 2026-10-14 · S4 · 항해 탭 보강·한국어 확인 (접근성은 뒤로)
- 한 일: 4cf1060 커밋. 스펙 `ui-voyage-a11y.md`. 항해 탭: 해역 카드(이름·n/50 막대·해역 보스까지·해역 보스 이름+약점 칩·다음 해역),
  오프라인 시간당(offlinePreview(savedAt+1h))·최대 8시간, 순풍 남은 시간. `WeakChips`·`remainingText` 공용으로 뺌.
  한국어 넘침 테스트(360×640·400×800: 시트·소환 결과·환생 창·복귀 팝업·운영자 패널·튜토리얼·항해 탭) — 360에서 소환 결과 별 줄 0.4px 넘침 찾아 고침.
  접근성(48dp·라벨) 점검은 첫 실행에서 탭 4개 모두 실패 → S1 지시로 도트 UI(ui-quality-v1) 뒤로 미룸(테스트 묶음은 보관).
  `check --full` 통과(64.6s, 위젯 164개).
- 다음 할 일: 골든 승인 → 커밋 → ui-quality-v1 스펙(기준: 이미지참고용 전투 v0.3·도트 v0.2)

### 2026-10-14 · S4 · 개인정보 옵션·운영자 표식·환생 실제 함수
- 한 일: main(S5 어댑터·a9ffda0 환생) 머지. ui 임시 NoAds·NoopAnalytics 삭제 → `adapters/` 것 사용. `adOfferProvider`가 AdMobAds.ready를 구독(광고가 뒤늦게 로드돼도 버튼이 뜸).
  ① 설정 ‘개인정보 옵션’(AdMobAds.privacyOptionsRequired일 때만 → showPrivacyOptions). ② `operatorMarker = '__OPERATOR_PANEL__'`를 운영자 패널 루트 ValueKey로 실제 참조.
  ③ 환생 카드 = 경제 `rebirthPreview`(임시 타입 삭제), 잠김 막대는 이번 회차 스테이지/minStage. 환생 결과 팝업(환생 횟수 증가 → 조각 +N·보너스, 상태 차이로 판단).
  `check --full` 통과(67.8s, 위젯 146개). 항해 탭이 보이는 골든 3장 변경.
- 다음 할 일: 골든 승인 → 커밋. 세이브 v4 오면 알림 토글

### 2026-10-14 · S4 · 광고·오디오·분석 포트 자리 (S5 요청서 platform-ui-ports)
- 한 일: b75f8b2(항해 탭·환생) 커밋. 스펙 `ui-ads-audio.md`(S1 지시). `adsPortProvider`(기본 NoAds)·`audioPortProvider`(null)·`analyticsPortProvider`(Noop).
  광고 버튼 = `adOfferProvider(placement)`(포트 isReady && 경제 canWatchAd && 튜토리얼 아님) → `show` → rewarded일 때만 GrantAdReward. 버튼마다 이득 숫자:
  상자 ×5·젬30(상자 아래), 순풍 30분×2(배지 아래), 함포 지원(보스 도전 아래), 무료 소환(소환 탭), 오프라인 ×2(받기 뒤 광고가 준비됐으면 창을 열어 둠).
  `battleGameProvider` → `BattleGame(audio:)` + 설정 효과음·배경음 → setVolumes. 이탈 분석: 시작·탭 전환·스테이지 변경 → setLastSeen.
  광고가 없으면 자리도 차지하지 않아 골든 변화 없음. `check --full` 통과(78.4s, 위젯 142개).
- 다음 할 일: S5 어댑터·세이브 v4 오면 교체·알림 토글, S2 환생 함수

### 2026-10-14 · S4 · 항해 탭·환생(보물지도)
- 한 일: 71c9509(보스 약점) 커밋. 비어 있던 항해 탭에 해역 이름·스테이지·최고 스테이지 + 환생 카드(조각·보너스, 가능하면 이번 획득·다음 조각까지·보물지도 버튼, 불가면 해금 안내와 막대).
  확인 창(잃는 것/그대로/얻는 것) → Rebirth. 값은 `rebirthPreviewProvider`(UI 임시 타입, 기본 null) — S2 환생 함수 오면 교체·타입 삭제.
  골든 2장 추가, 항해 탭이 보이는 3장 갱신. `check --full` 통과(42.1s, 위젯 133개).
- 다음 할 일: 골든 승인 → 커밋. S2 환생 미리보기 함수 대기

### 2026-10-14 · S4 · 환생·보스 약점 스펙
- 한 일: 46f958f 커밋(경제 함수 연결, 골든 8장, M3 계획 done). 스펙 초안 `docs/specs/ui-rebirth-boss.md` — 항해 탭 환생 카드·확인 창, 보스전 약점 칩.
- 다음 할 일: 승인 → 계획 → 가짜 provider로 환생 화면, 약점 칩(테이블만으로 가능)
- 진행: 스펙 승인(S1), main 553e883(경제 타입 game_core.dart로) 머지. 보스 약점 칩(보스 이름 + 약점 계열, 전장 오른쪽 위) 구현 — 약점 없는 보스·보스전 아님이면 숨김. tableText에 보스 이름 13개 추가.

### 2026-10-14 · S4 · 경제 함수 연결 (가짜 provider → 실제)
- 한 일: c772b68(운영자 패널 2차) 커밋. main 4d480ff(경제 B1~B10)·c4aed47(`game_core/economy_views.dart`) 머지.
  ui 임시 타입(GoalView·GoalKind·CollectionBonusView·QuestView·AttendanceView·AttendanceReward) 삭제 → 경제 타입 사용.
  provider 본문: nextGoal·collectionBonus·chestReward·dailyQuests·attendance, 순풍 배지는 tailwindRemaining. 퀘스트 보상은 meta.dailyQuestRewardGems,
  출석 칸은 JsonReader(gems | summon+minRarity), 도감 ‘다음까지’ = nextAt − owned. 테스트 가짜 값은 경제 타입 + 실제 테이블 출석 보상.
  샘플 화면에 실제 목표 막대·퀘스트 아이콘이 나와 골든 8장 재생성. `check --full` 통과(66.8s, 위젯 122개). TODO(economy) 0개.
- 다음 할 일: 골든 승인 → 커밋 → 계획 ui-m3-meta 완료 처리

### 2026-10-14 · S4 · 운영자 패널 2차
- 한 일: 스펙 ‘2차’ 절(S1 승인). 선원 묶음: 출전 선원마다 스킬 즉시(OpCastSkill), 출전 전원 전설/신화 첫 레벨(OpSetCrew, rarities levelMin 46·61).
  튜토리얼 묶음: 1~6단계·끝(OpSetTutorial). 경제 묶음: 보물상자(OpSpawnChest)·순풍 +30분(OpGrantTailwind, ads.json durationSec). `operator/meta_group.dart`.
  패널이 길어져 테스트는 scrollUntilVisible, 골든은 400×1300. ‘→’ 글리프가 글꼴에 없어 문구에서 뺌. `check --full` 통과(61.2s, 위젯 122개).
- 다음 할 일: 골든 승인 → 커밋. 경제 B 함수 교체 대기

### 2026-10-14 · S4 · 선원 초상
- 한 일: a75054d 커밋(출석 가짜 값 = 결정 20·20·30·30·40·50 + 영웅 확정). main c3e96fa(도트 팩 v0.2) 머지 →
  `CrewPortrait`(assets/<crews.json portrait>, 32×32 최근접 확대, 없으면 사람 아이콘)를 선원 카드·소환 결과 카드에. 카드 높이 조정(선원 최소 194, 결과 카드 0.5).
  골든 전에 이미지를 디코드하는 `precacheImages` 하네스 추가. 초상 40장 존재 테스트. `check --full` 통과(60s).
- 다음 할 일: 골든 2장 승인 → 커밋. 경제 B 함수 교체 대기

### 2026-10-14 · S4 · 레이아웃·접근성 점검, 퀘스트 줄마다 받기
- 한 일: de99d01 커밋(M3 골든 승인). `layout_test.dart`: 360×640(en/ko × 샘플 4개 × 탭 4개, 설정), 800×360 가로, 한국어 화면 문구, 아이콘 tooltip, 글자 대비.
  찾은 문제 2개 수정 — ① 360폭에서 선원 카드 7px 넘침 → 카드 최소 높이(400폭 배치는 그대로) ② 순풍 배지 대비 3.5:1 → 배경 black87.
  사용자 결정(main c691a83·fe981fd): 퀘스트마다 젬 보상, 줄마다 `ClaimDaily(questId)` → 퀘스트 시트를 줄마다 받기로. `check --full` 통과(위젯 115개).
- 다음 할 일: 골든 8장 승인 → 커밋. 경제 B 함수가 오는 대로 provider 교체
- 남은 문제: 화면 방향 미결(세로 고정 가정) — 가로는 넘침만 없게 안전망 테스트

### 2026-10-14 · S4 · M3 ⑦ 소환 결과 + 골든
- 한 일: f6a177a(퀘스트·출석) 커밋. `lastSummon`이 생기면 소환 결과 창(SummonResultGate): 카드 뒷면 → 눌러서/모두 뒤집기 → 등급 테두리·영웅 이상 강조·NEW,
  다 뒤집으면 확인 → AckSummonResult(+ 튜토리얼 4단계면 TutorialAck(4)). 소환 버튼의 임시 Ack 제거. 출석 칸 높이 맞춤.
  M3 영어 골든 4장 생성. main 다시 머지(레인 검사 merge-base) 후 `check --full` 통과(위젯 101개).
- 다음 할 일: 골든 승인 → 커밋 → 경제 함수가 오는 대로 provider 교체

### 2026-10-14 · S4 · M3 ④ 퀘스트·출석
- 한 일: 전장 왼쪽 위(순풍 아래) 퀘스트·출석 아이콘 1개, 받을 것이 있으면 빨간 점 → 하단 시트(최대 70%, HUD 안 가림):
  퀘스트 4줄(종류별 문구·진행·완료), 모두 달성 보상·받기(ClaimDaily)/받음, 출석 7칸(지난 날 체크·오늘 강조·7일차 소환권)·받기(ClaimAttendance).
  값은 `dailyQuestsProvider`·`attendanceProvider`(기본 null = 아이콘 숨김) — S2 B7·B8 오면 본문 교체. `check --full` 통과(위젯 90개).
- 다음 할 일: ⑦ 소환 결과(계약 대기), 경제 함수가 오는 대로 provider 교체, 골든

### 2026-10-14 · S4 · M3 ⑥ 튜토리얼
- 한 일: b2adadb(상자) 머지됨, main 8196057(new_player만 tutorialStep 1) 머지. 튜토리얼 말풍선(전장과 탭 패널 사이 줄, 건너뛰기 항상, 1·6단계 확인 → TutorialAck),
  가리킬 위젯을 `TutorialSpot`으로 감쌈(탭 아이콘·대포 강화·보스 도전·10회 소환·일괄 합치기·목표 막대). 4단계는 10회 소환 직후 TutorialAck(4) — 소환 결과 화면이 생기면 닫을 때로.
  `adOffersAllowedProvider` = 광고 준비됨(`adsReadyProvider`, 지금 false) && 튜토리얼 아님. 테스트 하네스는 기본으로 튜토리얼을 끝낸 상태로 그림(`keepTutorial`).
  스펙에 ⑦ 소환 결과 연출 추가(S1 요청). `check --full` 통과(위젯 84개).
- 다음 할 일: S2 B7·B8 오면 ④, 소환 결과 계약 오면 ⑦, 그 뒤 골든 3~4장

### 2026-10-14 · S4 · M3 ② 보물상자
- 한 일: cb9482f(①③⑤) 머지됨. 세이브 v3(main 16dda02) 머지. 상자: `battle.chest`가 있으면 전장 논리 좌표에 탭 영역(→ TapChest) + 가라앉기 링
  (ticksLeft / (ads.chest.floatSec × 1000 / tickMs)), 금액은 `chestRewardProvider`(기본 숨김). 전장 상자(`battle.area`) 안에 렌더와 같은 좌표로 겹침. `check --full` 통과(위젯 77개).
- 다음 할 일: S2 B7·B8 오면 ④ 퀘스트·출석 시트

### 2026-10-14 · S4 · M3 ①③⑤
- 한 일: b56dde8 스펙(승인)·요청서·계획. 순풍 배지(전장 왼쪽 위, 1초마다 다시 그림, h:mm/mm:ss, 배율은 ads.json),
  목표 막대(HUD 아래, `nextGoalProvider`), 선원 탭 도감 보너스 줄(`collectionBonusProvider`) — 둘 다 기본값 null(숨김), S2 B1·B9 오면 본문 교체.
  `clockProvider`를 `ui/state/clock_provider.dart`로 옮기고 테스트 하네스가 샘플 savedAt으로 고정. `check --full` 통과(위젯 70개대).
- 다음 할 일: 골든 승인 → 커밋 → S1 세이브 v3·S2 상자 규칙 오면 ② 상자

### 2026-10-14 · S4 · M3 메타 스펙
- 한 일: 3e45c65 코어 루프 커밋(골든 7장 승인, 경제 offlinePreview·summonCostFor 연결). `docs/specs/ui-m3-meta.md` 초안(목표 막대·상자·순풍·퀘스트/출석·도감·튜토리얼)과
  요청서 `docs/contracts/requests/ui-m3-meta.md` — 상자·튜토리얼 단계·‘받았나’가 GameState에 없어서 계약·세이브 v3 필요.
- 다음 할 일: 승인 → 계약·경제 함수가 오는 순서대로, 그 전엔 가짜 provider로 화면·테스트
- 남은 문제: 튜토리얼 문구 키 `tut.*`(설계서) vs 레인 접두어 규칙 — S1에 질문

### 2026-10-14 · S4 · 코어 루프 화면
- 한 일: 스펙 승인(3e6bb84) → 3b8e377 보스 도전·파밍 표시. 설정 화면(HUD 톱니, 9항목 → SetSetting, 앱 언어 = settings.lang),
  `battleGameProvider`가 BattleGame을 만들고 설정 4개를 JuiceSettings로 넘김, 운영자 ‘렌더’ 묶음(라이브·데모·부하, 성능 표시, 히트박스),
  복귀 오프라인 팝업(`OfflineRewardGate`: 시작 첫 프레임 + resume 다음 프레임, 중복 금지, 받기만). `check --full` 통과(위젯 60개).
- 다음 할 일: M3 메타 화면 스펙(`ui-m3-meta`)
- 마무리: main e883272 머지 → `offlinePreviewProvider`를 경제 `offlinePreview`로 연결(TODO 제거), 소환 비용 `summonCostFor`(첫 10연이면 ‘무료’)
- 남은 문제:
  - 골든 글꼴(SDK Roboto)에 한글이 없어 설정의 ‘한국어’ 버튼이 네모로 그려진다 — Galmuri 도입 때 해소
  - resume 직후 프레임이 없을 수 있어 `ensureVisualUpdate`로 직접 요청한다

### 2026-10-14 · S4 · 운영자 패널 커밋, 코어 루프 스펙
- 한 일: dbb986f 운영자 패널(골든 S1 승인), main 298b02c(저장·복원) 머지 315e0ab — `flutter pub get` 후 `check --full` 통과.
  `docs/specs/ui-core-loop.md` 초안(보스 도전·복귀 오프라인 팝업·설정 화면·운영자 렌더 묶음). main 1c31c32 다시 머지 — main이 옛 커밋(dbb986f)을 머지한 뒤 레인 검사가 main 파일을 ui 변경으로 잡던 문제 해소.
- 다음 할 일: 승인 → 계획 → 테스트 먼저 → 구현
- 남은 문제: 오프라인 미리보기 함수가 없어 S2에 `offlinePreview` 요청(S1 중계). 일시정지 저장 때 savedAt 갱신 여부 확인 요청

### 2026-10-14 · S4 · 운영자 패널 1차
- 한 일: b5aa3e6 (전장 주입점·골든 재생성·스펙, S1이 main 머지). 운영자 패널: 샘플 4개 → `OpLoadState`(SaveCodec.migrate 경유),
  배속 1/2/4, 무적·쿨타임 0, 보스 소환, 스테이지 이동, 골드·젬 지급. 열기는 HUD 스테이지 글자 5번(`if (kOperator)`일 때만 제스처 등록),
  하단 시트 최대 70% 높이(HUD 안 가림), 바깥 어둡게 안 함. 세이브 v2 머지 후 `check --full` 통과(위젯 테스트 41개).
- 다음 할 일: 골든 승인 → 커밋 → 다음 계획(항해 탭·설정 화면 — 설정이 생기면 운영자 열기를 버전 글자로 옮김)
- 남은 문제: `kOperator`가 상수라 앱 안에서 제스처→패널 경로는 테스트 못 함(게이트 위젯 단독 테스트로 대신)

### 2026-10-14 · S4 · 전장 분리와 운영자 패널 스펙
- 한 일: 렌더 레인의 새 전장 그림이 들어오며 UI 골든 4장이 깨짐(전장 영역만 22% 차이). S1 결정 B — UI 골든은 HUD와 탭 패널만 본다.
  home_screen에 `battleViewBuilderProvider` 주입점, UI 테스트는 빈 상자로 바꿈. `BattleGame(feed, tables)` 전달. 골든 재생성(미커밋, S1 승인 대기).
  운영자 패널 1차 스펙 초안 작성. main 머지(`sample_states.g.dart` 포함) 후 `check --full` 통과.
- 다음 할 일: 승인 → 골든·home_screen·스펙 커밋 → 운영자 패널 테스트 먼저 → 구현

### 2026-10-14 · S4 · 탭 화면 1차 구현
- 한 일:
  - 스펙 `docs/specs/ui-tabs.md` 승인(S1, 사용자 위임 확인) → 단계별 커밋:
    7b3e83b 상태 구독(`gameStateProvider`·`CommandSink`) · 630d1b7 상단 HUD + ui ARB + 테이블 nameKey 문구(`tableText`) ·
    3f6fa8c 배 탭 (S1이 main에 1차 머지) · e1d1bf0/f122f8f 소환 탭 · d4e7fd4 선원 탭
  - 경제 함수 사용: `partEffect`·`partCost`·`rarityOfLevel`·`summonCost`·`canSummon`·`promoteStatus`. UI에 계산식 없음
  - 엔진 연결(main c20e043) 뒤 20Hz 갱신 대비: 모든 위젯이 `gameStateProvider.select`로 필요한 값만 구독
  - 영어 골든 4장 `apps/game/test/goldens/en_*.png` — SDK Roboto/MaterialIcons를 읽어 실제 글자로 그린다(Ahem 네모 대신)
- 검증: `tool\check.bat --full` 통과(위젯 테스트 30개)
- 다음 할 일: 골든 커밋 → 항해 탭(해역 지도·환생), 배 탭 꾹 누르기·자동 강화·배 등급 막대, 선원 상세 창, 무료 광고 소환·증표 상점, 설정, 운영자 패널
- 남은 문제:
  - 영어 선원 이름이 5열 격자에서 말줄임된다(“Octo the B…”). 선원 상세 창에서 전체 이름을 보이거나 4열로 바꿀지 다음 계획에서 정한다
  - 골든은 Windows에서 생성. 다른 OS에서는 글자 렌더 차이로 골든이 깨질 수 있다
  - 운영자 “샘플 상태 불러오기”는 fixtures를 앱 에셋으로 등록해야 해서 보류
  - 주의: 생성된 l10n 함수의 인자 순서가 ARB 문구 속 순서와 다를 수 있다(`uiSummonPity(count, rarity)`). 호출 전에 생성된 시그니처를 확인

### 2026-10-14 · S4 · 레인 시작
- 한 일: worktree `D:\Projects\pde-ui`(lane/ui) 진입, 레인 브리핑·계약·테이블 확인, 스펙+계획 초안 작성.
- 소환 확률은 설계서(65/27/7/1)가 기준 — S2가 `rarities.json`을 맞췄다(골든에 반영).
- main e4edf73 머지(레인이 `docs/specs/<레인>-` 소유) → 스펙을 `docs/specs/ui-tabs.md`로 분리.
