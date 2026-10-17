# 진척: platform 레인 (S5, worktree pde-platform, 브랜치 lane/platform)

## 2026-10-18 늦은 밤 · S5 · 스토어 샷 개편 후 장면·폰 읽기 전용 측정
- **현재 위치**: store-shots-v3(0a90be73) main 머지됨 — 굽기는 slot 순서 S2 → S4 → S5. 폰 측정(프레임·메모리·온도 3회) 진행 중 → 표를 S1에.
- 장면 8: HD 무리·피버 v2·대보스 브레이크(폭풍해 80)·연쇄 번개(볼트·범고래·수달, 120)·새 동료 카드·선원 상세·10연 소환·환생 지도. 도우미 store_shot_kit.dart.
- 배운 것: 파이썬 open(…,'w')는 윈도에서 CRLF로 쓴다 — newline='' 필수. 장면 후보는 엔진만 짧게 돌려 이벤트 틱을 먼저 확인.

## 2026-10-18 늦은 밤 · S5 · 쏘기 직전 예고·상세 피해 줄·BGM 믹스
- **현재 위치**: review/enemy-windup 08fccf30 — S4(피해 줄 UI) 검토·S1 머지 대기.
- 한 일: EnemyWindup(ranged·boss·volley, waves.top.windupSec 0.4, sim 불변 시험), 선원 상세 피해 줄(#13), BGM 기본 믹스 0.7.
- 남은 ⬜(전부 폰·사람): 실기기 광고·UMP·알림·소리 확인, Firebase 수신, app-ads.txt 판정, 개인정보처리방침 게시, 실기기 손맛·60fps·HD 성능 재측정.
- 배운 것
  - 무적이면 보스 기본 포탄 이벤트가 아예 안 나온다(combat이 무적 검사를 먼저) — 보스 발사 시험은 무적 끄고.
  - 셸에서 `cat > 파일`을 입력 없이 두면 명령이 멈춘다 — 파일 쓰기는 파일 도구로.
  - 예고 0(끔) 처리: '남은 틱 == 예고 틱' 비교는 예고 0일 때 0 == 0으로 잘못 켜진다 — 0 확인 먼저.

## 2026-10-18 밤 늦게 · S5 · HD 굽기 성능·폰 확인표
- **현재 위치**: 내 몫 끝 — hd-portrait main 머지, hd-bake-perf(ea854ae0)는 S3 lane/render 6b7833b6에 포함(미리 굽기·저사양 384 얹음), device-check c3168345 S1 대기.
- 한 일: HD 굽기 측정(밀도 4: 40종 430ms·37MB, 밀도 6: 84MB, 보스 1.6~7MB) → 캐시 상한 14장 → 48MB. 폰 확인표 22줄(docs/plans/active/device-check-2026-10-17.md).
- 배운 것: 텍스처 캐시는 장 수가 아니라 바이트로 — 종마다 크기가 30배 다르다.
- 다음: S1 지시 대기. rotation smoke는 S2 밸런스 검진이 대신(생략).

## 2026-10-18 밤 · S5 · HD 초상(UI)
- **현재 위치**: review/hd-portrait 7aa98f42 — S4(UI 두 파일)·S3(렌더) 검토 대기. hd-bosses-a는 main 머지됨.
- 한 일: HdPortrait(render) — 종 그림을 UI 칸에 바로(정지/animate, HD 아니면 도트 fallback). 도감 MonsterSprite·BossPortrait(현상금·도감 보스·이름표·보스 도전)·보스 컷인 연결.
- 다음: 검토 반영. 재개 지점: rotation+duel smoke, 폰 확인표.

## 2026-10-18 저녁 · S5 · HD 배 보스 무리 12종
- **현재 위치**: review/hd-bosses-a 9d41f427(main 2876a4b1 위) — S3 검토 대기. HD 묶음 A는 main 머지됨.
- 한 일: S3와 보스 나눔(S3 = 대보스·생물 보스·해역 보스, S5 = 배 무리) → 공용 몸 boss_ship.dart + 12종 + 비교 골든 hd_bosses_a.
- 배운 것: 보스 특성(장갑·회피 등)은 렌더가 실시간으로 켜고 끈다 — 시트에 굽지 않는다. 작은 부품(금관)은 굵은 외곽선에 묻히니 크게.
- 다음: S3 검토 반영. 남은 일(재개 지점): rotation+duel smoke, 폰 확인표.

## 2026-10-18 오후 · S5 · HD 몬스터 묶음 A 10종
- **현재 위치**: review/hd-a 4bb6505a — S3 승인(검토 3건 반영: extent 1.2~1.3, 작은 얼음게 extent 같게, HdSpecies.muzzle + 원거리 7종 자리), S1 머지 중. review/k-windows-s5 7dcb0e53(창 개편 + 보상 연출)은 S4 UI run 대기.
- 한 일
  - 설계 노트 docs/specs/platform-hd-monsters-a.md(S2 노트 B와 같은 형식·실루엣 규칙 같은 문구).
  - S3 HdKit 새 구조(옆모습·0.8초 고리·species/<kind>.dart)로 10종: 갈매기·폭풍갈매기·눈갈매기(공용 seabird), 성게, 날치, 복어, 얼음게·작은 얼음게(반 크기), 펭귄, 물범. 확인 골든 hd_trial_a.
  - 공용 부품: S2 underwater·bubbles·wing을 같은 글자로, 내 spikes·birdWing은 hd_kit_parts.dart.
- 다음 할 일: S3 검토 반영, 원거리 '쏘기 전 밝아짐'(TopEnemies muzzle 제안) 답 기다림. rotation+duel smoke, 폰 확인표.
- 배운 것
  - 공용 부품 이름이 겹칠 땐 한쪽 것을 같은 글자로 맞춰 넣으면 합칠 때 충돌이 없다.
  - 0.8초 고리 그림에서는 몇 초 주기 상태(쏘기 직전)를 표현할 수 없다 — 렌더 이벤트 쪽 몫.

## 2026-10-18 · S5 · 디자인 개편(쿵푸할매 스타일) — HD 아이콘·바다 v2·보상 연출·창 개편
- **현재 위치**: main 머지됨 — sea-v2(해역 팔레트·외곽선 소품). S4 UI run 대기 — review/k-windows-s5 7dcb0e53(창 개편 S5 몫 + reward-fx-wire). HD 아이콘(review/hd-icons f2c2abb4)은 S4 run에 포함. 다음: HD 몬스터 절반(코랄·폭풍·빙하 잡몹 약 13종) — S3 기준서·공용 벡터 도구 기다림.
- 한 일
  - HD 아이콘 42종(tools/art/gen_hd_icons.py 코드 SVG → assets/ui/hd 1x·2.0x·3.0x, 칸 85% 자동 채움, 탭은 바깥 테). PixelSprite hd는 fit contain.
  - 바다 v2: 해역별 깊은 팔레트(fx_map topSea.regions), 흘러가는 외곽선 소품 TopSeaProps(해역 세트·배 길 밖·화면당 4·Picture 캐시·피버 0.5 미만 생략), check --full 초록 → main.
  - 보상 연출 RewardBurst(회전 빛기둥 5색·출처 그림 흔들림→열림·등급색 IconCell + 외곽선 숫자·회전 튕김 정렬·lite) + 붙이기(광고 상자·도감 수집·보스 처치 창 전·소환 결과 빛).
  - 창 개편: 환생 7종·일일·오프라인을 PixelDialog·SubRibbon·Skin.inset·IconCell·OutlineText로.
  - 운영자 보스 목록 42종·특징 칩, 선원 역할 키(S2 조정).
- 배운 것
  - lint를 고칠 때 의미 있는 인자(fit: BoxFit.contain)를 같이 지우지 말 것 — 아이콘이 원본 크기로 묶여 '작게 보인다'로 돌아왔다.
  - Image에 fit이 없으면 scaleDown(원본보다 키우지 않음).
  - k2에서 Skin.track은 남색 — 옅은 '잠김' 바탕으로 쓰면 글이 묻힌다(D3D1EA 사용).
  - 300줄 제한: main과 합칠 때 남의 변경으로 넘을 수 있다 — 합친 뒤 줄 수 먼저 확인.

## 2026-10-18 새벽 · S5 · 통합 run 머지, 디자인 개편(쿵푸할매 스타일) ② HD 아이콘 시작
- **현재 위치**: 디자인 개편 최우선(docs/plans/active/design-kungfu-style.md). 내 몫 ② HD 아이콘 — 시안 S1 확인 대기.
  생성기·시안은 scratchpad/icons(gen_hd_icons.py — 37개: 재화·탭·부위·상자·체크·계열 11종, compare_all.png·fam.png, icon-map.md).
- 한 일
  - 통합 run(hud-layout + lane/ui + swap-compare + crew-preview + crew-traits-2 + lane/economy) check --full 초록 → main e8a2720f.
  - 운영자 보스 소환 목록 42종·특징 아이콘·칩(review/operator-bosses 81bf28f9, 시험 통과 — 머지 대기).
  - 선원 역할 키(review/crew-role 5dbeb75e, S2 검토 반영 — S2 재적합과 맞춰 나중에 머지).
- 재개 지점(중단한 작업)
  - 폰 확인표 docs/plans/active/device-check-2026-10-17.md — 아직 안 씀(S1 요청 ②). 첫 할 일: 오늘 main 머지 목록(git log --since 2026-10-17 main) → 기능마다 '어디서·무엇을' 한 줄.
  - rotation+duel smoke(5명×1시간) — slot 받으면.
  - HD 아이콘: 확인받으면 tools/art/gen_hd_icons.py로 옮기기 → assets/ui/hd(1x 32·2.0x 64·3.0x 96) → UiSprites 교체 → SkinIcon FilterQuality → LICENSES OWN → 4기기 골든.
- 배운 것
  - 통합 run 전에 머지할 브랜치를 모두 미리 합쳐 두면 slot 시간이 테스트에만 쓰인다.
  - 같은 작업 폴더에서 --full이 도는 동안 브랜치를 바꾸면 안 된다 — 그동안은 scratchpad에서 읽기·생성만.

## 2026-10-17 심야 · S5 · 보스전 v2·고침 2건, 공격 미리보기, hud-layout 다시 맞춤
- **현재 위치**: main 머지됨 — 보스전 v2·duel-fix(기절 중 standoff 파고듦)·proto-fix(피버 8자가 초당 30으로 묶이던 내 v2 버그). slot 대기(S2 → 나): review/hud-layout 9dd036cc(최신 main + lane/ui 30ef8463, #9 C 환생 말풍선 뺌, 배 체력 막대 전폭·보스 버튼 막대 위) → test/ui·proto 골든 일괄 + --full → 해시. 검토 대기: review/crew-preview 8ccf2134(S3 렌더·S4 UI), review/swap-compare 7638613c(S4 지적 3건 반영). 그 뒤 rotation+duel smoke(5명×1시간).
- 한 일
  - 보스전 v2: 배가 화면 가운데 높이로 올라가 보스와 마주 보며 반대편 궤도, 머리 초당 180°, 끝나면 제자리(waves.top.bossDuel shiftY·rise·turnDegPerSec). 프레임 띠 골든.
  - duel-fix: 보스 기절 중 배가 standoff 안으로 → 배가 보스와 standoff보다 가까워지지 않게(돌진 중 보스는 제외). boss_clear_advances 젬 160.
  - proto-fix: 머리 회전만으로 '결투 중'이 되어 피버 이동이 묶임 → 결투·복귀가 아니면 자리는 그대로. proto 골든 글꼴(BREAK!).
  - 공격 미리보기: 공용 하네스 game_core CrewPreview(앱 엔진과 따로, 무리 ↔ 보스 5초 번갈아, 결정론) + 렌더 CrewPreviewView(가상 상자 폭 400단위) + 상세 패널·등급 탭 + 시험.
  - 검토: S2 melee-guard OK.
- 배운 것
  - '상태 플래그'에 부수 조건(머리 회전)을 섞으면 다른 기능(피버 이동)이 조용히 묶인다 — 이동 제한과 회전 제한은 따로.
  - dart test 증분 캐시가 낡으면 `part of` 오류가 남는다 → .dart_tool/test 지우고 다시.
  - 끝없는 애니메이션 위젯은 UI 시험 하네스에서 끌 스위치(Provider)를 처음부터 둔다(pumpAndSettle).
  - 보고 전 출력 끝줄을 직접 확인(game_cli '통과'를 잘못 보고했다가 정정).

## 2026-10-17 늦은 밤 · S5 · 사용자 폰 버그 3건, 선원 정리 2안, 운영자 오늘 기능, 도감 v2 순환 23종
- **현재 위치**: 머지 대기 — review/sfx-stuck 4e8b681b(소리 버그, S3 OK) · review/fever-motion-2 5627db41 · review/damage-label e2821c3a · review/crew-traits-2(EnemyView.rooted 포함, 밤 재적합과) · review/hud-layout 4f098cfc(골든·--full slot) · review/rotation-bosses 0e5f5f98(boss-traits bc033482 위, smoke slot 요청).
- 한 일
  - 소리 버그(가끔 타격음 없음): 원인 = 내 power_policy가 방치(60초 무입력)에 효과음을 껐다. 절전 화면만 끔 + 발열 심함은 동시 수만 줄임 + 재생 자리 2초 반환·고장 플레이어 교체·장면 시계 되돌림 리셋. 회귀 테스트.
  - 피버 모션 진정(원 없음·기울기 15°·넓고 긴 S자), 선원 칸 '피해 12K'+칼.
  - 선원 정리 2안 엔진(관통 가속·부메랑·물기 속박·휩쓸기·해적왕 강타) + 설명 + EnemyView.rooted.
  - 운영자 '오늘 새 기능' 6개(main 머지) — 그때 main에 bossBreak 표가 없어 브레이크가 꺼져 있던 것 발견(S2 C8로 해결).
  - 도감 v2 보통 보스 23종 라이브(순환·특성·이름). 검토: S2 boss-traits(삼키기가 호위 먹음·분열 몸 특성 상태 미상속 지적).
- 배운 것
  - '조용히' 같은 정책은 게임 성격(보면서 두는 게임)부터 확인 — 방치를 '안 듣는 중'으로 보면 안 된다.
  - 테스트 이름에 작은따옴표를 넣으면 셸·파이썬 치환에서 깨진다 → 따옴표 없는 이름으로.
  - 표에 값이 없으면 기능이 조용히 꺼진다 — 운영자 버튼·점검 테스트로 드러난다.

## 2026-10-17 밤 · S5 · 통합 --full 머지, 피버 v2(#24 배 모션·#23 음악), #13·#14 UI, 검토 4건
- **현재 위치**: #24·#23 main 머지됨(청취는 다음 폰 빌드). 머지·slot 대기: review/hud-layout 4f098cfc(#9 A·C·D·#26 + 상세 '지금 합치기' → MergeAllCards(crewId)) — 골든 일괄 갱신·--full은 slot(S4 lane/ui 머지 뒤), E는 그 뒤. review/crew-traits-2 f25e3497(선원 정리 2안 엔진 + 설명 + 요청서 EnemyView.rooted, S2 검토 OK). review/operator-today 0d980567(운영자 '오늘 새 기능' 6개). 발견: main skills.json에 bossBreak 표가 없어 브레이크가 꺼져 있음 — S1에 알림.
- 한 일
  - #13·#14 UI(review/damage-ui): 선원 칸 아래 피해량, 보스 처치 2.6초 뒤 선원별 피해 창(MVP).
  - 통합 --full: 줄 수(events·top_geometry)·리터럴·하드코딩 문구 고침, ARB는 3-way 키 합치기(scratchpad arb_union.py), 골든은 최신 main 위 다시 굽기. boss-duel 키는 보류 → S1이 ① 채택(S2 재조정).
  - boss-duel sim(5명×1시간): 보스가 화면 밖에서 조준 안 되던 숨은 난이도가 사라져 보스전 크게 쉬워짐(10단위 첫 도전 25→100%).
  - #24 flow 모션(8자 곡선·가감속·드리프트 기울기·가끔 원 돌기) + 4기기 프레임 띠 골든. #23 bgm_fever(168 BPM, 조 바꿈) + 곡 전환 페이드.
  - 검토: S2 break-cooldown·bounty-card·break-view·crew-traits OK, fever-swarm은 top_geometry 300줄 초과 지적.
- 배운 것
  - main이 계속 움직인다 → --full 직전에 반드시 다시 머지(이번에 세 번). 단독 실행과 파일 실행 골든이 다를 수 있다(파일 기준으로 굽기).
  - 브랜치 전환 뒤 l10n gen이 낡아 컴파일 실패 → merge_arb + gen-l10n 먼저.
  - 보고 해시는 `git log -1`로 확인하고 보낸다(잘못 보낸 적 있음).

## 2026-10-17 저녁 · S5 · S4 짐 덜기 — UI #19·#20·#12·#11·#16, S2 검토
- **현재 위치**: 리뷰 브랜치 머지 대기(S1 순서 crew-damage → boss-duel → sail-hold → sail-ui). review/sail-hold ef3fc1f3 · review/sail-ui f2fbd543(S4 검토 반영 완료, 기본 check 통과) · review/crew-ui f2d8bbc3(S4 검토 대기). boss-duel sim은 5명×1시간 짧게(slot), 정밀 비교는 밤.
- 한 일
  - #19 UI: 상자 창 '출항!'(StartVoyage), sailHold면 전장 가운데 56dp '출항!' + 안내(TutorialSpot 'sail.start'). #20: 빠른 항해 띠 → 우상단 패널(n/m·막대·보스 연속 격파·건너뛰기 48dp).
  - #12: 상세 '레벨을 올리는 이유'(공격력 +x% 초당 a→b · 카드 n장 · 승급까지 n레벨) + 56dp '지금 합치기'. #11·#16: 카드 '↑ +n' 알약, 일괄 합치기 56dp 'n명'. 값은 경제 crewGrowth·mergeGain(economy/crew_growth.dart, S2 경로).
  - S2 review/break-cooldown 4cfd351f 검토 OK(참고 2: 분열 몸 쿨다운 미상속, UI 게이지 0).
- 배운 것
  - 셸(sed·awk·python heredoc)로 ARB에 `
`을 넣으면 실제 줄바꿈이 돼 JSON이 깨진다 → Edit 도구로.
  - 다른 브랜치에서 check를 돌리면 생성물(l10n gen)이 그 브랜치 ARB로 다시 만들어진다 → 브랜치를 바꾼 뒤엔 merge_arb·gen-l10n부터.
  - 폰트에 '↑' 글자가 없어 네모로 나온다 → 아이콘으로.
  - 골든 실패를 '원래 빨강'으로 단정하지 말 것 — 최신 main 머지 후 다시 본다(이번엔 낡은 기준 탓이었음).
- **다음 할 일**: S4 crew-ui 검토 반영 → slot 때 boss-duel 5명×1시간 · 머지 전 --full(최신 main 머지 후) · 스토어 굽기는 피드백 반영 뒤.

## 2026-10-17 오후 · S5 · S1 배정 4건 → 사용자 피드백 21건 재배정(#13·14·10·19)
- **현재 위치**: S1 머지·slot 대기. 셋 다 main e1f4258b(rage 정리) 위로 merge, dart 테스트 통과 — review/crew-damage b70f09eb · review/boss-duel 502dff7a(sim 비교 2회 slot 순번 4번째) · review/sail-hold 86516d1f(#19 승인·구현, game_cli sim 한 줄은 S2 확인) · review/sail-ui 27683b45(#19 출항 버튼·#20 우상단 패널, S4 검토 대기). lane/platform 0093dff0.
- 한 일
  - 도감 이벤트 소비처: 엔진은 DexSeen·DexFirstKill을 이미 냄, 소비처 없었음 → 분석 dex_seen·dex_first_kill(0392cda). 화면 쪽은 S4.
  - 도감 v2 보스 42종 초안 docs/specs/platform-bestiary-v2-regions.draft.json + 덧대기 검사 테스트(bestiary_draft_test). kraken_titan(S3 확정), 튜토리얼 1~3 enemy_ship 고정 → regions 선택 키 rotationFromStage(bossAt, battle 경로 3줄). 수치는 S2, 보통 보스 23 id는 S1이 S3에 전달.
  - 스토어 샷 02 → 02_fever_strike(피버 게이지 0.95), listing ko/en 문구(e791a17). **굽기는 보류**(피드백으로 화면이 바뀜).
  - 야간 sim 점검 tool/nightly_sim.py(+test): 컴파일 → 100명×30일 → 벗어남 요약, 잠금·메모리 반감·log.csv(822c195). 실행 안 함.
  - #13·14 선원별 피해: Damage.crewId로 거의 되지만 넘친 피해·보스 추적·확정값 때문에 계약 추가(요청서 platform-crew-damage, 승인) → BattleView.crewDamage·BossCleared.crewDamage/mvp.
  - #10 보스 잘림: 원인 standoff 100 > 카메라 반폭 90. 배가 보스 반대쪽으로 standoff×0.5 비켜 섬(40/초, 피버 pose 길 재사용, 카메라 그대로), waves.top.bossDuel.
  - #19 미리 시작: Rebirth 다음 틱에 breakthrough가 바로 구간을 엶(엔진에 출항 전 상태 없음) → Progress.sailHold·StartVoyage(승인·구현, hold 중 무리·보스·돌파 없음).
- **다음 할 일**: ① slot 오면 boss-duel sim 비교(기본 vs --set waves.top.bossDuel.shift=0, 20명×3시간) ② S1 rage 커밋 뒤 crew-damage rebase → check --full ③ S4 검토(sail-ui) 반영, 골든 '확인 창 ko'·'배 스킨 ko' 실패가 기준에서도 나는지 slot 때 확인 ④ 스토어 6세트 굽기는 피드백 반영 뒤 ⑤ 폰 작업은 S1 지시 뒤.
- 남은 문제: 도감 초안 수치(S2)·보통 보스 그림(S3). boss-duel 앱 골든(렌더)은 안 돌림.
- 배운 것: shapeField는 한 틱에 두 번 불린다(TopBounty.prepare와 _round 둘 다 _sync) — 상태를 가진 이동은 Field.tick으로 한 걸음만.

## 2026-10-17 · S5 · 보급·선체 체력·궁극기 제거/보스 브레이크·발열 — 사용자 퇴근으로 멈춤
- **현재 위치(멈춤)**: S1 머지 대기 — review/thermal cfc6754(발열 5건), review/fever-break 2b5955d(+ lane/platform 06e33fe 메모). 머지됨 또는 S1 처리 중 — review/fast-sail-supply 28ec135, review/hull-hp e0185d6.
- 한 일: 빠른 항해 보급(S2 함수 연결 + 보급 뒤 체력 최대 새로 채움, 83-1 침몰 0) · 선체 강화 즉시 체력 반영 · 궁극기 제거 → 피버 첫 일격 + 보스 브레이크(사용자 직접 지시) · 발열 5건(60Hz 요청·오디오 상한·thermal 단계·화면 켜짐 확인·thermal_log.py).
- **남은 할 일(다음에)**:
  1. 스토어 스크린샷 '02 궁극기' 장면을 '피버 첫 일격'(또는 보스 브레이크)으로 바꾸고 6세트 최종 굽기(지금 42장 — 02만 빠짐)
  2. 폰 허락 뒤: release_smoke, thermal_log.py로 발열 전후 비교(30분), 60Hz 적용 확인(dumpsys display)
  3. 렌더 lite·30fps를 thermalLevelProvider로(S3에 알림), 도감 dex 세이브(S2·S4) 엔진 이벤트 자리
  4. 도감 v2 데이터: S3 대보스 그림 id(boss_sea_croc 등 6) 나오면 S2 숫자로 regions.json
  5. 야간 sim 점검(메모리 한도 안 순차)
- 배운 것: 보급처럼 '전장을 만든 뒤 배 상태를 바꾸는' 길은 Field의 체력 최대가 따라가지 않는다(만들 때 한 번) — shapeField에서 함께 갱신.

## 2026-10-17 새벽 · S5 · 계열 행동 v3 엔진 5단계 완료, 도감 v2 엔진
- **현재 위치**: 계열 v3 엔진(출격·레이저·원형·집속·시차 타격) main 8195a8c. 도감 v2 엔진 review/bestiary 9100d02 S1 머지 대기 — 보스·잡몹 데이터는 S3 그림이 나오는 대로 S2와.
- 한 일: 출격 CrewSortie · 레이저 빔 유지(배 따라감) · 원형 탄막(빈 방향 탄) · 집속 자탄 BombletBurst · 기관포 연발·물수제비 튕김·파동 링 시차 타격 · 보스 순환·대보스·먹물·삼키기·분열(둘 다 잡아야 격파)·자폭·떼 · 등급별 aim 전 등급 · Gun export · 보스 firstRestSec·enemy_ship blast·돌격대 attackMul · 운영자 선원 시험·세이브 백업 · 현상금 테스트 실제 경제 · release_check 통과 · 기획 계열 v3·도감 v2 · 아침 확인 목록 v2.
- 배운 것: **커밋하지 않은 변경이 있으면 `git merge main`이 조용히 거절된다** — 출력에서 CONFLICT만 거르면 놓친다. 머지 뒤 `git merge-base --is-ancestor main HEAD`로 확인한다(골든 실패를 내 탓으로 잘못 볼 뻔).
- 남은 일: 스토어 스크린샷 최종 굽기, 야간 sim 점검, release_smoke(폰 허락 뒤).

## 2026-10-16 밤 · S5 · 빠른 항해 돌파·지그재그·돌격대·등급 보정·운영자 선원 시험·계열 v3·도감 v2
- **현재 위치**: 계열 행동 v3 사용자 승인(추천대로) → 엔진 출격(강습·공중)부터. 도감 v2 기획 초안 S1 확인 대기.
- 한 일(모두 main 또는 S1 머지 대기): 빠른 항해 돌파(가속 리듬 build→rush→finale, 건너뛰기, 실은·넘친 골드) · 피버 좌우 → 지그재그(느린 값, 배 기울기) · 돌격대(넉백·기절·끌기 면역) · 전설 이상 rarityTempo·aim.legend/mythic·맞은 자리 폭발 · 보스 firstRestSec·enemy_ship blast · 운영자 선원 시험·세이브 백업(review/operator-crews, S4 검토) · 현상금 테스트 실제 경제로 · release_check 통과(배포 aab 운영자 표식 0) · 아침 확인 목록 v2(15분) · 기획 계열 v3·도감 v2.
- 진단: 보스전 배 피해 0.29% = 보스가 3초 안에 죽어 첫 패턴(3.05초)을 못 봄 → firstRestSec.
- 남은 일: 계열 v3 엔진(출격 → 레이저 → 원형 → 집속 → 기존 타이밍), S2 rankAims 전 등급·Gun export(S4), 스토어 스크린샷 최종 굽기, 야간 sim 점검, release_smoke(폰 허락 뒤).

## 2026-10-16 저녁 · S5 · 선원 개성 v2 엔진 1~3단계, 보스 행동 v2
- **현재 위치**: 개성 v2 1~3단계 main 머지(d07663c). 보스 행동 v2 review/boss-patterns 36a5e75 S1 머지 대기. 표 값(aim 40명·traitScale·turtle/pelly/pumpum legends)은 S2.
- 한 일: 조준 8종·탄 비행·예측·MISS(AttackMissed) · 쿨다운 남은 몫 넘기기(0.3초가 0.35초로 돌던 버그) · 특징 일반 40%부터(개수형은 발마다 확률) · aim power = 간격 비례(같은 DPS) · 보호막(turtle)·낙뢰(pelly)·피버 서포트(pumpum, 사용자 추가 지시) · 보스 패턴 4종(탄막·돌진·소환·장판) + 바다 괴물 돌진 보스(붙은 시간 68% → 5.5%) · store_shots 옆모습 갈래 삭제(S3 요청).
- 배운 것: 탄 예측은 한 번 고쳐 계산하면 탄속과 대상 속도가 비슷할 때 크게 틀린다 → 만나는 시각을 이분 탐색. 소환처럼 적 목록을 바꾸는 단계는 사본으로 순회.
- 남은 일: 실기기 재측정(폰 허락 뒤), 스토어 스크린샷 최종 굽기(체력 막대 뒤).

## 2026-10-16 오후 · S5 · 피버 오라·배 위협 엔진, 보호막·번개 선원, 보스 패턴 기획
- **현재 위치**: review/fever-aura 0b782d5 → review/ship-threat 002cda9(위에 쌓음, check --full 통과) S1 머지 대기. 표 키는 S2(오라 91e9833), regions `ranged`는 S2 요청으로 내가 ship-threat에 넣는다.
- 한 일: 피버 오라(배 둘레 녹이기 + 앞쪽 적 빨리) · 배 위협 (a) 원거리 적 EnemyFired·탄 비행 (b) 가까이 등장 EnemyEmerging · 선원 개성 v2에 보호막(turtle)·낙뢰(pelly) 7절 · 보스 패턴 기획 docs/specs/platform-boss-patterns.md.
- 진단: '보스가 박치기만' = 돌발 ambush sea_serpent(일반 적 취급) + 렌더가 BossFired를 그리지 않음(본 보스 엔진은 정상).
- 남은 일: S2 hurtShip 커밋 뒤 lava·적 탄을 hurtShip으로 · 개성 v2 엔진 → 보호막·번개 → 보스 패턴.

## 2026-10-16 · S5 · 스토어 스크린샷 재굽기(main 537387f), 현상금 사냥 탑다운 계획·요청서
- **현재 위치**: 현상금 사냥 B0 계약(S2)을 기다리는 중 → 받으면 review/bounty에서 B1 엔진.
  - [x] 스토어 스크린샷 48장(폰·태블릿7·10 × ko·en) — 배 미표시는 렌더 시계 문제(S3 c039bbd)였고 고강화와 무관(내 오진, S1에 정정)
  - [x] 현상금 탑다운 세부 계획(platform-bounty-topdown.md, S1 승인: 피버 멈춤·standoff 100·침몰=실패+반환·일요일 아무 보스)
  - [x] 요청서 B0·B2(S2) · B3(S3, 체력 막대·상태 아이콘·T4-3 2단계 뒤) · B4(S4, 체력 막대 색·선원 상세 뒤)
  - [x] B1 엔진(review/bounty 6d69ce6, S2 승인) + 보물 상선 직진(5a2db91)
  - [x] B5 플랫폼(review/bounty-b5 772d0f5): 분석 bounty_*, 백그라운드 후퇴
  - [ ] B2(S2)·B3(S3)·B4 연결(S4) 대기
  - [ ] 스토어 최종 굽기(체력 막대 새 모양 뒤)

## 2026-10-15 밤 ~ 10-16 · S5 · 배 충돌 크기 통합·스폰 패턴·아침 확인 목록·스토어 스크린샷
- **현재 위치**: S1 밤새 배정 4건 중 ①②④ 완료, ③ 거의 완료(렌더 버그 대기).
  - [x] ① 배 충돌 크기 = 그림 크기(review/ship-hitbox 5653a01, S2·S3 승인): waves.top.shipScale 한 키, ship_tiers 배율 1 선체(반폭·뱃머리·배꼬리), 선체 단계 커짐, 일치·보이는 거리 테스트
  - [x] ② 스폰 패턴(review/spawn-patterns 6cb6d4b): swarm·scatter·arc, 황금 물고기 자동 조준 제외, 폭풍 적 이동 ×1.3
  - [x] ④ 아침 10분 확인 목록 초안(platform-device-check-topdown.md, c62c486)
  - [~] ③ 스토어 스크린샷 탑다운·스킨(14c827d): 폰·태블릿7·10 × ko·en 구움. 후반 배가 탑다운에서 안 그려지는 렌더 버그(S3에 넘김) 고친 뒤 다시 굽기
- 남은 문제: 후반 상태(all_crews_mythic)의 배 미표시(S3), 60fps 상한 뒤 폰 재측정(폰 연결 뒤, 읽기 전용).
- 배운 것: 리뷰 브랜치 기준이 오래되면 골든 실패가 '내 변경' 탓처럼 보인다 → main을 먼저 받고 본다.

## 2026-10-15 · S5 · T4-2 main 머지(33c9b5e), 폰 성능 측정, 배 충돌 크기 제안
- **현재 위치**: T4-1·T4-2(+T4-B S2 균형) main 머지 완료. T4-2b(S2)·T4-3(S3)·T4-4(S4)에 시작 해시를 알림 → 끝나면 T4-5(S5: 스토어 스크린샷·release_smoke·실기기).
- 한 일
  - T4-2에 S2 균형(40351cd)을 머지해 check --full 통과(fb4db44) → S1 머지
  - 폰 읽기 전용 측정(docs/store/device-perf-2026-10-15.md): 120fps 안정, CPU 약 100%, 5분에 +3°C, 메모리 누수 징후 없음. gfxinfo 대신 frametimeline 사용
  - 제안서 docs/plans/active/platform-ship-hitbox.md: 배율 키 하나(waves.top.shipScale)를 엔진·렌더가 함께 읽기 + 그림과 엔진 일치 테스트
- 남은 문제: 60fps 제한 제안(S3), 제안서 결정(S1), 새 빌드 재측정.

## 2026-10-15 · S5 · 사용자 버그 '적이 일정 간격에서 멈춰 보임' 수정 (review/topdown-approach-fix dcc29f2)
- 원인: ① 접촉이 반경 28 원(배는 길쭉 — 옆구리 11 떨어져 멈춤) ② 화면 끝 → 몸통 6~9초, 사거리 끝에서 맞고 죽어 정지처럼 보임(프레임 띠로 확인).
- 수정: 선체 캡슐 접촉(ship_tiers topHalfWidth·topHalfLength), waves.top.mobSpeedScale 2. 몸통 접촉 39 → 129, 접촉 공격 68 → 243. 회귀 테스트·골든 4장.
- 도구: apps/game/test/proto/top_strip_test.dart(TOP_STRIP=<폴더> — 실제 기록을 프레임 띠로).
- 다음: T4-2 엔진 옆모습 삭제(WIP 브랜치 review/topdown-t4-2), T4-B 균형은 S2·S3.

## 2026-10-15 · S5 · 탑다운 T4 리드 시작(S1 지시, 사용자 "옆모습 안 쓴다")
- **현재 위치**: T4 세부 계획(docs/plans/active/topdown-migration.md, d3f6089).
  - [x] T4-1 기본 top(review/topdown-t4 bfe4030, check --full) — S2 검토 대기
  - [ ] T4-B 탑다운 균형(S3·S2): balance crews top 비율 강습 1.22·투척 1.15·수중 0.70·관통 0.42
  - [~] T4-2 엔진 옆모습 삭제(review/topdown-t4-2 8fe4db2) — 코드 완료, check는 balance crews만 실패 → T4-B 뒤 머지
  - [ ] T4-3 렌더(S3) ∥ T4-4 UI(S4) → T4-5 출시 점검(S5)
- 한 일
  - Settings.battleView 기본 top, main.dart 임시 줄 제거, sim·시나리오 기본 top
  - 옆모습 전용 테스트를 side로 고정, balance crews --view(기본 side 유지)
  - 탑다운 관통 조준 개선, 골든 5장 재굽기
  - 레인별 할 일을 S2·S3·S4에 직접 보냄
- 남은 문제: 탑다운 선원 균형 ±10% 밖(관통·수중 약, 강습·투척 강) — 모양 조정이 필요하면 S5가 TopAim 연결.

## 2026-10-15 · S5 · T1 머지 뒤 마무리 — 일반 빌드 side 고정, 탑다운 sim 비교, 렌더 점검
- **현재 위치**: T1 머지 완료(main 74567dd까지).
  - [x] main.dart: 일반 빌드에 저장된 battleView=top을 시작 때 side로(6c83947, T4 때 제거)
  - [x] sim --view + 비교표(리뷰 브랜치 review/topdown-sim-view 9424bc9): 진행 곡선 ±10% 안, 환생 뒤 보스 간격만 +41%(목표 안). 조정은 S2
  - [x] 렌더 점검표(03b2a88): 빈칸 2개 — 상자 위치(S2 chest), 피격 방향(ShipDamaged.fromX/Y 제안)
- 추가(review/topdown-hits 35ca5d5): ShipDamaged 피격 방향(탑다운만), 보스 출발을 접근 원 바로 밖(bossSpawnRadius). 보스 간격 3.95 → 3.45초(side 2.15) → S2에 bossSpawnRadius ≈ 152 제안.
- 추가(review/topdown-swarm 4c830e2): 줄 간격 swarmSpacing·방향 가중 spawnWeights 연결(S2 표 26e0879 위). sim: 환생 회복 −20%(보스 간격 해결), 오프라인 8시간 강화 5 → 1(목표 밖, S2 무리 크기 쪽으로 넘김).
- 주의: git stash는 워크트리끼리 공유된다 → 쓰지 않고, 비교 기준은 임시 worktree로.
- 다음 할 일: S2 검토 → S1 머지. S3 추가 요청 반영.
- 남은 문제
  - 운영자 토글은 S4 몫(S1 결정 b: '렌더 준비 중' 표시).
  - 폰 작업은 S1 재연결 알림을 기다리는 중.

## 2026-10-15 · S5 · 탑다운 시험판 → 사용자 결정 '탑다운으로' → T1 엔진 2D화, 환생 v2·현상금 C1 문서
- **현재 위치**: 탑다운 전환(docs/plans/active/topdown-migration.md) T1 리드.
  - [x] T0 검토(S2 계약 채택 + 거리·해류·무리 의견, 2da8665)
  - [x] T1-1 topdown/ 모양(42e1dc4)
  - [x] T1-2 기존 battle 파일 훅(리뷰 브랜치 `review/topdown-t1-hooks` d3377a2·739dc1b, S2 검토 대기 → S1 머지)
  - [x] 등급별 배 반경 topRadius 28·29·32·32, bossStandoff 100, 카메라 180×320(리뷰 브랜치 8270538)
  - [x] 탑다운 시나리오 2개(top_swarm_all_sides, top_boss_standoff) + replay 관찰 키 mode·quadrants·bossAtStandoff
  - [x] 운영자 패널 side/top 토글 요청서(S4, 74567dd) — T2 전 렌더 어긋남 때문에 여는 시점은 S1 결정
  - [ ] 균형 sim ±10%(S2) · S2 검토 OK → S1 머지 대기
- 한 일
  - 시험판: lib/proto/ 결정론 2D 시뮬·코드 도트·drawAtlas, PROTO 빌드(앱 ID .proto, 본 게임과 나란히 설치). S1이 설치했고, 사용자 판정은 '탑다운으로 진행'.
  - 환생 v2 기획서(1f49c73): 상점 9칸·명예 외형·스킨·즉시 상자·미리보기·횟수별 해금·세이브 v6. 사람 결정 4개.
  - 현상금 C1 계약 요청서(21c994b): bounty.active 포함, 구현 보류. 세이브 v6은 환생 v2와 합치기를 권함.
  - T1
    - BattleGeometry(Side = 지금 함수 그대로, Top = 2D)
    - 8계열 2D 조준(거리 = 배 둘레 → 적 가장자리)
    - 사방 1~3 무리 스폰, 접근 원 밖 해류로 도착 시간을 옆모습과 맞춤
    - 보스 standoff 원 돌기
    - 밀기 방사·끌기 2D, 포구·방향 이벤트
    - 옆모습은 sim 20명·3시간 결과 파일이 main과 cmp 동일. 리뷰 브랜치에서 check --full 통과. 탑다운 테스트 18.
- 다음 할 일: S2 검토 반영 → S1 머지. S2 표 추가(separation·bossOrbitDegPerSec·viewWidth/Height·approachBoost 5·ship_tiers.topRadius) 뒤 등급별 반경 연결.
- 남은 문제
  - 강습 range 40 < 보스 둘레 거리 → 옆모습 규칙(보스면 range 무시)을 그대로 씀.
  - 좌우 보이는 폭 90이라 첫 발이 늦어지는지 sim 확인 필요(S2).
  - 폰 작업(시험판 60fps gfxinfo, QA, 메모리 A/B)은 S1 재연결 알림 대기.
  - 기존 파일 훅은 레인 밖이라 리뷰 브랜치로 냈다(lane/platform에는 topdown/만).

## 2026-10-15 · S5 · 재실행 멈춤 버그 원인 확정·수정 (S24 실기기, 사용자 자리 확인 후)
- 원인(logcat 근거): ① 첫 화면 BACK이 액티비티를 **finish**(`wm_finish_activity app-request`) → 다시 열면 같은 프로세스에서 새 Flutter 엔진.
  ② 템플릿 `taskAffinity=""` 때문에 런처로 열 때마다 **새 작업·새 엔진**. ③ 이전 엔진 정리 `performDestroy`가 **8349ms**(배경음이 백그라운드에서도 재생 중이던 때) — 메인 스레드(Flutter 3.29+ 합쳐진 스레드)가 막혀 새 화면이 스플래시에 머묾. 배경음을 멈춘 뒤엔 103ms.
- 수정: MainActivity `finish()`가 작업 맨 아래면 `moveTaskToBack`(Android 16 예측형 뒤로 가기는 popSystemNavigator를 안 거침) · manifest `singleTask` + 기본 affinity · onPause/onResume에 배경음 pause/resume · FlameAudioSdk 효과음 timeout 타입 오류(`onTimeout: () {}`) 수정.
- 확인(실기기): 60초 전투 → 첫 화면 BACK → 홈(같은 pid, finish·destroy 0) → 다시 열기 0.94초, `boot:` 0줄(엔진 재사용). 수정 전 약 10초.
- 발견: device_shots의 `in_front`(topResumedActivity)가 Samsung에서 런처가 앞인데도 우리 앱이라고 답함 → `dumpsys window` mCurrentFocus로 바꿔야 함(다음 커밋).

## 2026-10-15 · S5 · 재실행 멈춤 1차 대응 + 매일 콘텐츠 4종 기획서
- 한 일(버그, S1 위임): MainActivity.popSystemNavigator → moveTaskToBack, SDK 초기화 3초 제한(Firebase·오디오 목록 → Noop·무음), onDetach 정리, `boot:` 단계 로그, EngineHost.pause 두 번 안전.
  원인 확정은 실기기 재현이 필요 — **사용자가 폰 앞에 있다는 S1 확인 전엔 입력 금지**(대기 중).
  실수: check 출력을 `| tail`로 받아 실패(레인 밖 engine_host_test.dart)를 놓치고 커밋 → 미머지 커밋 2개를 soft reset으로 합쳐 정리. **check는 종료 코드로 판단한다.**
- 한 일(기획): docs/specs/platform-content-{overview,achievements,bounty,crew-bond,voyage-log}.md — 피로 규칙과 부딪히는 곳(시즌·한정·티켓)을 '쌓이는 티켓·자동 지급·첫 등장 의상·주말은 보너스만'으로 푼 안, 테이블 키·세이브·명령·이벤트·UI·수용 기준·레인 분담, 우선순위(업적+주말 → 현상금 → 선원 → 일지).

## 2026-10-15 · S5 · 실기기 캡처 스크립트 실기기 검증(S24) — 덤프 실패 대응, 복귀 창, 안전장치
- 한 일: 덤프 실패(Flame이 늘 움직여 "null root node") → 좌표를 배치 규칙으로(dumpsys window 상태·내비 바 틀 + wm density). S24 실측과 맞춤(설정 1012,171 · 퀘스트 878,171 · 탭 y 2126).
  창 감지는 그림으로(상단 바 바탕 27→13이면 막) → 밝은 기본 버튼(받기, 실기기 색 67,118,185) 누르기 → 남으면 BACK. **캡처마다** 확인(복귀 창이 늦게 뜬다). 앞 화면과 같으면 경고. 00_start.png 남김. 테스트 13.
- **사고(입력 안전)**: 3번째 실행에서 앱이 뒤에 있었는데 탭을 보내 홈의 전화 앱을 열고 그 안을 눌렀다(통화 상태 0 확인 — 통화 없음). 원인: 누르기 전 앞 앱 확인이 없었음.
  → 누르기·BACK 전 **매번 topResumedActivity가 우리 앱인지 확인, 아니면 멈춤**, 덤프도 우리 앱이 앞일 때만, 버튼이 안 열렸으면 BACK 안 보냄(테스트로 고정).
- 발견(앱 버그 의심, S1): 첫 화면에서 BACK으로 앱이 닫힌 뒤(프로세스 살아 있음) 다시 열면 **스플래시에서 멈춤**. 같은 pid에서 "FlutterJNI was detached … Could not send" 경고가 쏟아짐. force-stop 후 새로 열면 정상.
- 다음 할 일: S1이 BACK→재실행 멈춤 재현·수정(main.dart 엔진 재생성/타이머 정리 쪽 의심).

## 2026-10-15 · S5 · 실기기 캡처에 퀘스트·설정, 스토어 스크린샷 재굽기(배치 v2·6해역)
- 한 일: device_shots.py에 상단 바 퀘스트 시트·설정 화면(접근성 라벨로 찾기, 없으면 건너뜀, BACK 키 하나만) + 테스트 8.
  store_shots: 탭 이동을 `Key('tab.N')`로(v2 탭 바), 탭 화면 5장을 해역별(폭풍 60·빙하 120·유령 270·심연 220·폭풍 75)로, 보스는 화산해 200 용암 고래(가운데·최근 공격 없는 틱 고르기 `firstClear`).
- 발견: 폭풍해 번개 가오리는 관통 선원이 없으면 보호막이 내내 켜짐(청록 상자) → 장면에서 뺌. 폭풍해 51에선 중반 함대가 못 잡아 궁극기 게이지가 안 참 → 궁극기는 산호해 유지.
  ui: 영어 유령해에서 boss_weakness.dart:63 Row 13px 넘침 → 요청서 platform-ui-store-shots 3번에 추가. 보스 장면 패널의 "오프라인 골드 ~0/h"는 중반 함대가 스테이지 200에 있어서(실제 계산) — 거슬리면 장면을 바꾼다.

## 2026-10-15 · S5 · 세로 고정(+게임 카테고리), 실기기 캡처 스크립트
- 한 일: manifest `screenOrientation="portrait"` + `android:appCategory="game"`(debug 빌드·병합 manifest 확인). release-checklist A4 갱신.
  `docs/store/device/device_shots.py`(+테스트 7): adb 자동 탐색 → 기기 고르기 → 꺼짐·잠김이면 안내만(입력 없음) → 설치(선택) → 실행 → uiautomator 덤프로 탭 좌표(없으면 4등분) → 탭 4장 캡처 → build/device/shots/<시각>/·latest/.
- 발견: Android 16(API 36) 큰 화면 방향 무시에는 **게임 예외**(공식 문서: "Games (based on the android:appCategory flag)") → appCategory=game으로 태블릿도 세로 유지. 600dp 레이아웃 요청서는 불필요.
- 다음 할 일: S1 main.dart SystemChrome 세로 고정(diff 전달), 실기기 연결 시 스크립트 첫 실행 확인.

## 2026-10-15 · S5 · M5 출시 준비 문서: 비공개 테스트·콘텐츠 등급·출시 체크리스트
- 한 일: `closed-test.md`(공식 문서 인용: 2023-11-13 이후 개인 계정, 12명 × 연속 14일, 신청서에 피드백 수집 방법 요약 → 설문 2회·로그), `content-rating.md`(주제별 답·근거, 타깃 13+ 추천), `release-checklist.md`(A~E 항목·담당·상태).
- 확인(빌드 산출물): 병합 manifest에 AD_ID(AdMob) · FOREGROUND_SERVICE(androidx.work 2.7.0) · 정확한 알람 권한 없음. targetSdk 36(Play 2026-08-31 요건 충족).
- 발견: **화면 방향 고정이 없다**(manifest·코드) → 폰을 눕히면 가로. 세로 고정 + API 36 큰 화면(600dp+) 대응 결정 필요(A4).
- 다음 할 일: 사람 결정 5개(패키지 ID·화면 고정·영문 이름·타깃 연령·국가) → 나머지 진행.

## 2026-10-15 · S5 · 디자인 퀄리티 단계 계획(논의 자료), 다른 해역 장면 조사
- 한 일: `docs/store/design-quality-plan.md` — 벤치마크 7종(웹, 배치 수치 대부분 미확인을 명시), S24 캡처 대비 차이 E1~E11, 단계 ①배치 ②UI 스킨 ③전장 연출 ④폴리시(할 일·레인·완료 기준·규모), 논의할 것 3개.
- 발견: 팔레트 대비 — 글자는 충분(흰 16.5:1, 흐림 6.3:1, 골드 10.4:1), **패널 테두리 1.8:1**이 화면을 한 덩어리로 보이게 한다.
  다른 해역 스크린샷: 산호~화산 스프라이트 다 있음(심연·유령 없음). 중반 함대로 해역 보스 부르면 보스가 오래 남음(577틱) → 보스 장면 가능.
  동시 처치 장면은 함대 세기 조정이 날카로움(신화 lv75는 화면 밖에서 다 잡고, lv20~50은 못 잡음) → v2 머지 뒤 재굽기 때 다시.

## 2026-10-15 · S5 · 스토어 스크린샷 8장(ko·en)·그래픽 이미지 자동 굽기
- 한 일: `apps/game/test/store/store_shots_test.dart`(STORE_SHOTS=ko|en일 때만, 기본 check는 skip): 샘플 상태에서 실제 CoreEngine을 돌려 기록 →
  원하는 순간(동시 처치·궁극기·해역 보스)을 BattleScene·ScenePainter로 재생 → battleViewBuilderProvider로 실제 앱 화면에 넣고 1080×1920(411dp×2.625) PNG.
  운영자 명령은 엔진 기록에만(스테이지 이동·무리 30·무적·보스 소환), 화면엔 운영자 패널 없음. `docs/store/feature_graphic.py`: 아이콘 배 + 게임 스프라이트, 256×125 ×4.
- 발견: ① 재생은 시간 아니라 **위치**로 멈춰야 한다(배속 ×2 기록이라 끝을 지나 돌리면 이펙트가 다 사라짐). ② 정지 화면에 번쩍임이 찍히면 하얗게 씻김 → 끔.
  ③ 스테이지 37 무리(7마리)는 화면 오른쪽 끝에서 다 죽어 장면이 빔 → 산호해 44·무리 30. 신화 함대는 보스를 몇 초 만에 잡음 → 보스 장면은 중반 함대.
  ④ **아트 공백**: 폭풍해 이후 적 대부분·보스 10종·배 2등급 이상 스프라이트 없음(대체 도형/갈색 상자) → 전장은 산호해만. ⑤ ui: 360dp 소환 결과 0.7px overflow, 카드 이름 잘림 → 요청서 platform-ui-store-shots.
- 다음 할 일: 사람 승인. 아트가 채워지면 해역 다양화(폭풍해 보스 등).

## 2026-10-15 · S5 · 효과음·배경음 후보: CC0 조사 + 자작 칩튠 생성기 (사용자 지시 "음원을 최대한 신경 써서")
- 한 일: CC0 조사(서브에이전트 2개, 페이지 라이선스 원문 인용, 다운로드 없음) → `docs/store/audio-candidates.md`(id별 CC0 A·B vs 자작, 추천, 제외 목록).
  자작: `docs/store/audio-gen/chipsynth.py`(sfxr 방식, 표준 라이브러리만)·`gen_audio.py` → `docs/store/audio-preview/`(wav, 커밋 안 함, 결정론):
  fx_map 12종 ×3 + 추가 후보 cannon·coin, 해역 bgm 6곡(4채널, 이음매 없는 루프), 전투 10초 모의 믹스, `index.html`(한 페이지에서 듣기). 테스트 7개.
- 발견: 펄스 duty 12.5/25%의 DC 치우침(−0.13) → 0 평균 펄스 + DC 차단으로 고침. 게임은 hit·hit_crit만 변형 `_0..2`, 나머지는 `<id>.ogg` 하나(sound_director).
  ogg 인코더(ffmpeg 등)가 PC에 없음 → 사람 단계. Claude는 소리를 못 들으므로 평가는 지표(길이·피크·RMS·DC·이음매)와 설계 근거.
- 다음 할 일: 사람 청취·선택 → S1/S3가 ogg 변환·에셋 등록.

## 2026-10-15 · S5 · 아이콘·스플래시 적용
- 한 일: main 828953b 머지 → `apply_icons.py --src tools/art/icon --bg "#5AA9E6" --splash-bg "#5AA9E6"`: PNG 26장(mipmap 전경·배경·단색·예전, drawable 스플래시 로고)·XML 6개. debug 빌드 성공. 미리보기로 도트가 선명한지 확인.
  스크립트 수정: cp949 콘솔 UnicodeEncodeError(S3 보고) → stdout/stderr utf-8 reconfigure. Pillow 14에서 없어질 `getdata` → `getcolors`·`getextrema`.
  **버그**: 기본 `ROOT`가 `apps/`를 가리켜 스토어 아이콘이 `apps/build/store/`로 감 → `parents[3]` + 기본 경로 테스트(총 11개).
- 경고(의도로 보고 둠): legacy.png 둥근 모서리 투명 — Android 7.x 런처에서 모서리가 비친다.
- 다음 할 일: 실기기 결과 대기(아이콘 모양·테마 아이콘·스플래시 포함).

## 2026-10-15 · S5 · main(세이브 v4 알림 설정) 머지, Built-in Kotlin 경고 조사
- 한 일: main 7551e04 머지(Settings.notifications·main.dart enabled/onSettingChanged 연결 확인). Gradle 경고 조사 → `docs/store/android-release.md` 7절.
- 발견: 경고 원인은 템플릿의 `android.builtInKotlin=false`(firebase 최신판은 이미 대응, 플래그 때문에 KGP 적용). `true`로 바꾸면 `audioplayers_android` 5.3.0(최신)이
  옛 buildscript·junit5 플러그인 때문에 실패 → 되돌림. 지금은 할 일 없음, audioplayers 대응판이 나오면 다시.
- 다음 할 일: 실기기 결과 대기.

## 2026-10-15 · S5 · S1 main.dart 연결 머지 뒤 빌드 확인, 실기기 확인 절 초안
- 한 일: main(어댑터 연결 3e1efd6 포함) 머지 → `check --full` 통과(156.5초). `flutter build apk --profile` 성공(80.1MB), 운영자(`OPERATOR=true`) profile 성공(111.2MB).
  `release_check` 재실행: 표식 `__OPERATOR_PANEL__` 배포 aab 0회 · 운영자 apk 1회 → 통과(aab 54.4MB).
  `docs/plans/active/platform-device-test.md` = DEVICE_TEST.md "3. 플랫폼 확인" 절 초안(9항목, S1이 붙임). human-inputs.md: 아이콘 그림을 art(S3) 담당으로 옮김.
- 발견: Gradle이 일부 플러그인이 "Built-in Kotlin"을 지원하지 않는다고 경고(빌드는 성공). 앞으로 Flutter/AGP 올릴 때 막힐 수 있음 — 그때 플러그인 버전 확인.
  효과음 파일이 아직 없어 실기기에서 무음이 정상.
- 다음 할 일: 실기기 결과 대기. S2 meta-notify·S4 operator-test/save-failure 반영 뒤 main.dart TODO 교체 확인.

## 2026-10-15 · S5 · PC 재시작 뒤 재개: main 머지, 아이콘 적용 스크립트, 요청서 2개, 사람 입력 목록
- 한 일: main 머지(fast-forward, 25커밋) → `check --full` 통과(137.5초). S1에 main.dart 연결 권장안 전송(초기화 순서·no-op·kOperator·save 체인).
  `apps/game/android/icon/apply_icons.py`(+테스트 10개, Pillow): 원본 격자 PNG → 밀도별 최근접 정수 배율 mipmap, 적응형 XML, colors, 스플래시(11 이하 layer-list filter=false, 12+ values(-night)-v31), 스토어 512px.
  격자 크기·필수 파일·단색 2색이면 아무것도 안 쓰고 실패, 안전 원 밖은 경고. `OfflineFullNotifier.testRing()`(운영자용, id 2, 하루 기록·설정 무관, 테스트 1개).
  요청서 `platform-operator-test`(ui: 운영자 패널 광고 보기·개인정보 옵션·알림 10초 뒤), `platform-save-failure`(ui: diskFull·io 띠).
  런처 이름 `@string/app_name` — values `Pirate Dot`(영문 확정 전) / values-ko `해적도트 원정대`. `docs/store/human-inputs.md`(사람 입력 모아 보기).
- 다음 할 일: S1 main.dart 연결 → 실기기 확인(human-inputs.md 마지막 절). 아이콘 그림이 오면 apply_icons.py.
- 남은 문제: 계정·키·결정 대기 목록은 human-inputs.md.

## 2026-10-14 · S5 · 사용자 입력 반영(이름·개발자·연락처·웹사이트), Blogger app-ads.txt 조사
- 한 일: 게임 이름 해적도트 원정대(확정)·영문 Pirate Dot Expedition(확정 대기)·개발자 박은우·repo.dev88@gmail.com·웹사이트 rich-fire.blogspot.com을
  listing.ko/en·privacy-policy.ko/en·admob.md에 반영. Analytics 보존 기간은 '미정' 유지. app-ads.md를 Blogger 기준으로 새로 씀.
- 확인(curl): `/app-ads.txt` → 301 → `/ads.txt`(200, text/plain, 이미 `pub-8353634332299342` 한 줄), 없는 경로 404, robots.txt가 크롤러를 막지 않음.
- 확인 필요(단정 안 함): AdMob이 경로가 바뀌는 리다이렉트를 인정하는지(공식 문서에 없음 — AdMob 콘솔에서만 판정), 기존 pub ID가 AdMob 게시자 ID와 같은지,
  영문 개발자명 표기. 안 되면 대안: Firebase Hosting `<프로젝트>.web.app` 또는 GitHub 사용자 사이트를 Play 웹사이트로.
- 다음 할 일: S1 main.dart 연결·실기기 확인, M5에 AdMob 콘솔 app-ads.txt 판정.

## 2026-10-14 · S5 · 저장 견고화, 알림 문구 최종, 아이콘·스플래시 규격
- 한 일: 스펙 `platform-save`(S1 지시) → 테스트 먼저 7개 → `FileSaveStore`: write는 던지지 않음(실패는 `failure` = diskFull|io),
  일시 실패 3번 시도(50·200ms), 디스크 가득(28·112·39)은 재시도 없이 tmp 삭제, 백업 2단(bak→bak2), readBackup이 bak 깨지면 bak2(코어 loadSave 무변경).
  알림 문구 최종(설계서 4.9 톤, 재촉 없음) + 시간 `{hours}` = meta.offline.maxSec에서 계산. `docs/store/icon.md`(도트 정수 배율 격자 54·24·64px, 적응형·단색·스플래시 12+/11 이하, 적용 순서).
- 발견: `EngineHost.save()`의 `_saving.then(write)` 체인은 write가 한 번 던지면 이후 저장이 전부 건너뛰어진다 → 어댑터가 안 던지게 막음, S1에 catchError 이중 장치 권함.
  minSdk = Flutter 기본 24(Android 7.0) → 예전 아이콘(48dp)도 필요.
- 다음 할 일: S1 main.dart 연결·실기기 확인, 아이콘 그림이 오면 icon.md 4절 순서로 적용, `failure` 표시(ui 결정).
- 남은 문제: 루트 .gitignore에 `save.bak2` 없음(S1) — 테스트는 임시 폴더라 영향 없음.

## 2026-10-14 · S5 · 배포 검사 스크립트, 스토어 문구·개인정보처리방침 초안
- 한 일: S1이 0860520 머지(2497b11) → main 머지. `release-check` 요청서에 표식 상수·`tool/release_check.dart` 전문(의존성 없는 zip 리더) 추가.
  실제 빌드로 확인: `--marker op.invincible` → 배포 aab 0회 · 운영자 apk 1회(2분 41초) = 지금 배포 빌드에 운영자 패널 없음.
  docs/store: listing.ko/en(앱 이름·간단한 설명 80자·자세한 설명·스크린샷 8장 목록·그래픽 규격), privacy-policy.ko/en(+Play 데이터 보안 양식 대응표), app-ads.md.
  영어 문구의 배 등급·해역·콤보 이름은 게임 ARB(en)와 맞춤(Sloop·Pirate Warship·Phantom Sea 등).
- 발견: 개인정보처리방침이 "설정 > 개인정보 옵션"(UMP 재동의)을 약속한다 → ui-ports 요청의 이 버튼은 '선택'이 아니라 EU 출시 전 필수.
  app-ads.txt는 도메인 루트여야 해서 GitHub **프로젝트** Pages로는 안 된다(사용자 사이트나 커스텀 도메인).
- 다음 할 일: S1 main.dart 연결 뒤 실기기 확인. 사람 입력 대기: 연락 이메일·개발자명·게임 이름 확정·Analytics 보존 기간.
- 남은 문제: 스토어 문구는 게임 이름 확정(ADR-0002) 전 임시. 스크린샷은 사람이 캡처.

## 2026-10-14 · S5 · M4 어댑터 4개 + Android 빌드 설정
- 한 일: 스펙 승인(S1) → 요청서 4개(9bd27da) → AdMob 테스트 앱 ID 급히 분리 커밋(6f40e02) → main 2번 머지(deps 7개 포함).
  테스트 먼저(가짜 SDK, 26개 — 수용 기준 1~21 전부) → 구현: `adapters/ads/`(AdMobAds·NoAds·GoogleAdsSdk·테스트 ID),
  `adapters/notify/`(OfflineFullNotifier·notify.json 기록·LocalNotificationsSdk·문구 `parts/platform.*.arb`),
  `adapters/analytics/`(startAnalytics·SdkAnalytics·NoopAnalytics·firebase_sdk), `adapters/audio/`(AudioAdapter·FlameAudioSdk).
  android/: 예약 알림 수신기·부팅 권한, Firebase 수집 기본 꺼짐, desugaring, google-services·crashlytics 플러그인은 `google-services.json` 있을 때만, key.properties 릴리스 서명.
  docs/store: firebase.md · android-release.md · admob.md.
- 검증: `check --full` 통과(62.8초). `flutter build apk --debug` 성공(수용 23), `flutter build appbundle --release --obfuscate`가 키 없이 성공(수용 22, 51.8MB).
- 발견: Windows에서 Kotlin "Could not close incremental caches"(프로젝트 D:, pub 캐시 C:) → `android/gradle.properties`에 `kotlin.incremental=false`.
  `MetaTable`에 `notifications.dailyMax`가 파싱되지 않음 → notify-setting 요청서에 추가. 하드코딩 문구 검사가 debugPrint의 한글도 잡음 → 로그는 영어.
  lane 소유권 검사는 `main...HEAD` 기준이라, S1이 내 커밋을 머지한 뒤엔 main을 다시 머지해야 merge-base가 맞는다.
- 다음 할 일: S1 main.dart 연결(어댑터 머지 때) → 실기기에서 테스트 광고·알림 확인, ui의 adsPortProvider·audioPortProvider 반영 확인,
  release-check 표식이 들어오면 수동 검사 실행. 그다음 스토어 문구 ko/en·개인정보처리방침·app-ads.txt(레인 할 일 6).
- 남은 문제: SDK 연결 파일(google_ads_sdk·local_notifications_sdk·firebase_sdk·flame_audio_sdk)은 단위 테스트 없음 — 실기기 확인 필요.
  운영자 모드 진입점(광고·알림 테스트)은 operator 소유 레인 몫(선택). iOS는 M6까지 no-op.

## 2026-10-14 · S5 · 레인 시작, M4 스펙 초안
- 한 일: main fast-forward(b306250). `docs/specs/platform-m4.md` 초안(광고 AdMob+UMP·로컬 알림·Analytics/Crashlytics·flame_audio·Android 내부 테스트 빌드, 수용 기준 23개),
  계획 `docs/plans/active/platform-m4.md`. 패키지 최신 버전 pub.dev에서 확인(2주 미만 버전은 피함).
- 발견: 설정에 알림 키 없음 → 계약 요청 필요(세이브 v4). UI에 AdsPort·AudioPort를 받을 provider 없음(`adsReadyProvider`만) → ui 레인 요청.
- 다음 할 일: S1 승인 → 요청서 → 테스트 먼저 → 구현.
- 남은 문제: SDK 의존성(S1 pubspec) 머지 전엔 SDK 연결 파일을 못 만든다.
