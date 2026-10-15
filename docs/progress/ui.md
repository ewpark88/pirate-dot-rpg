# 진척: ui 레인 (S4)

## 현재 위치
| 항목 | 내용 |
| --- | --- |
| 계획 | `docs/plans/active/ui-quality-v1.md` (v1·v2 승인, HUD 걷어내기·배 탭 줄 승인 대기) |
| 상태 | 화면 배치 v2(S24 실기기 피드백) 구현 — S1 승인·실기기 설치 확인 대기 |
| 기다리는 것 | 골든 승인 · S3 글리프로 숫자 도트 글자(계획 8) |

## 세션 로그 (최신이 위)

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
