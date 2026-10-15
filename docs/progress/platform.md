# 진척: platform 레인 (S5, worktree pde-platform, 브랜치 lane/platform)

## 2026-10-15 · S5 · 탑다운 시험판 → 사용자 결정 '탑다운으로' → T1 엔진 2D화, 환생 v2·현상금 C1 문서
- **현재 위치**: 탑다운 전환(docs/plans/active/topdown-migration.md) T1 리드.
  - [x] T0 검토(S2 계약 채택 + 거리·해류·무리 의견, 2da8665)
  - [x] T1-1 topdown/ 모양(42e1dc4)
  - [x] T1-2 기존 battle 파일 훅(리뷰 브랜치 `review/topdown-t1-hooks` d3377a2·739dc1b, S2 검토 대기 → S1 머지)
  - [ ] 등급별 배 반경(S3 크기, 표 대기)
  - [ ] 균형 sim ±10%(S2)
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
