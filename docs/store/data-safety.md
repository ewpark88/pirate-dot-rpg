# Play 데이터 보안(Data safety) 양식 — 답변 초안

- 2026-10-18, S5. 사람이 Play Console **정책 > 앱 콘텐츠 > 데이터 보안**에 입력한다. 법률 자문이 아니다 — 입력 전 사람이 검토.
- 기준: 지금 앱의 실제 SDK(`apps/game/pubspec.yaml`) — `google_mobile_ads` 9.1.0(AdMob + UMP), `firebase_analytics` 12.6.0,
  `firebase_crashlytics` 5.4.0, `flutter_local_notifications` 22.3.1. 계정·서버·결제 없음. 세이브는 기기 안 파일(`save.json`·`.bak`).
- SDK별 수집 항목 출처(2026-10-18 열람):
  - AdMob: https://developers.google.com/admob/android/privacy/play-data-disclosure
  - Firebase(Crashlytics): https://firebase.google.com/docs/android/play-data-disclosure
  - Google Analytics for Firebase: https://support.google.com/analytics/answer/11582702
- SDK 버전·기능(예: 인앱 결제, 랭킹, Remote Config)이 바뀌면 이 문서·개인정보처리방침 2항·`content-rating.md`를 같이 고친다(platform 레인).

## 1. 앱이 실제로 보내는 것 (코드 기준)
| 무엇 | 어디서 | 언제 |
| --- | --- | --- |
| 광고 요청·시청·보상(보상형 7곳: 상자·순풍·보스 지원·무료 소환·오프라인 2배·자동 강화·현상금 표) | AdMob SDK | UMP가 `canRequestAds` 참일 때만 광고를 요청 |
| 화면 보기(`screen_view`), 사용자 속성 `last_screen`·`last_stage` | Firebase Analytics | **UMP 동의(canRequestAds) 뒤에만 수집 켬** — 시작은 꺼짐(매니페스트 `firebase_analytics_collection_enabled=false`) |
| 게임 이벤트 6종: `bounty_start`·`bounty_clear`·`bounty_fail`·`bounty_sweep`·`dex_seen`·`dex_first_kill` (보스 id·단계·보상 수치만) | Firebase Analytics | 위와 같음 |
| 충돌 기록 + 사용자 키 `screen` | Firebase Crashlytics | **배포 빌드에서 동의와 상관없이**(`collectCrashes: kReleaseMode && !kOperator`) — 아래 4절 결정 필요 |
| 오프라인 보상 알림 | 기기 안 예약(로컬) | 서버 전송 없음 → 수집 아님 |
| 세이브 | 기기 안 앱 폴더 | 개발자에게 전송 안 함 → 수집 아님. 단 Android 자동 백업(기본 켜짐)이 사용자 본인 Google 계정에 백업할 수 있다(OS 기능, 개발자는 볼 수 없음) |

## 2. 콘솔 질문별 답
### 2.1 개요
| 질문 | 답 |
| --- | --- |
| 필수 사용자 데이터 유형을 수집하거나 공유하나요? | **예** |
| 수집하는 모든 사용자 데이터가 전송 중 암호화되나요? | **예** — 세 SDK 모두 TLS/HTTPS(위 출처) |
| 사용자가 데이터 삭제를 요청할 수 있나요? | **예** — 이메일 repo.dev88@gmail.com(개인정보처리방침 4항). 계정이 없어 '계정 삭제 URL'은 해당 없음 |
| 광고 ID를 쓰나요?(별도 '광고 ID' 선언) | **예** — 목적: 광고, 분석, 사기 방지. `com.google.android.gms.permission.AD_ID`는 AdMob이 합쳐 넣는다 |
| 가족 정책(아동 대상) | 아니요 — 타깃 13세 이상(`content-rating.md` 5절, 사용자 결정) |

### 2.2 데이터 유형 (수집 = 기기 밖으로 보냄, 공유 = 제3자에게 넘김. 우리 대신 처리하는 서비스 제공자는 '공유' 아님)
| Play 분류 > 유형 | 수집 | 공유 | 목적 | 근거 |
| --- | --- | --- | --- | --- |
| 위치 > **대략적인 위치** | 예 | 예 | 광고, 분석, 사기 방지·보안 | AdMob: IP 주소 '수집 및 공유', 대략적 위치 추정에 쓰일 수 있음 · Analytics: 마스킹 IP로 대략적 위치. 앱은 위치 권한 없음(정확한 위치 = 아니요) |
| 앱 활동 > **앱 상호작용** | 예 | 예 | 광고, 분석, 사기 방지·보안 | AdMob '사용자 제품 상호작용'(실행·탭·동영상 시청) 수집 및 공유 · Analytics 화면·세션·게임 이벤트 6종 |
| 앱 정보 및 성능 > **비정상 종료 로그** | 예 | 아니요 | 분석(앱 안정성) | Crashlytics 스택 추적(Google = 서비스 제공자) |
| 앱 정보 및 성능 > **진단** | 예 | 예 | 광고, 분석, 사기 방지·보안 | AdMob '진단 정보'(실행 시간·멈춤 비율·전력) 수집 및 공유 · Crashlytics 기기 메타데이터 |
| 기기 또는 기타 ID | 예 | 예 | 광고, 분석, 사기 방지·보안 | AdMob 광고 ID·앱 세트 ID(수집 및 공유) · Analytics 앱 인스턴스 ID·광고 ID · Crashlytics 설치 UUID |
| 개인 정보(이름·이메일·주소·전화 등) · 금융 · 건강 · 메시지 · 사진·동영상 · 오디오 · 파일 · 캘린더 · 연락처 · 웹 기록 · 기타 앱 활동(검색 등) | 아니요 | 아니요 | — | 입력·로그인·검색 기능 없음 |

### 2.3 유형마다 묻는 추가 질문
| 질문 | 답 |
| --- | --- |
| 일시적으로만 처리하나요?(ephemeral) | **아니요**(모든 유형) — SDK가 저장·집계한다 |
| 필수인가요, 사용자가 선택할 수 있나요? | **필수**로 답한다 — EEA·영국·스위스는 UMP 동의를 받지만 그 밖 지역은 끌 수 없다. (게임 설정 '개인정보 옵션'은 UMP 대상 지역에서만 보인다) |

## 3. 콘솔 입력 전 사람이 확인할 것
- [ ] AdMob 콘솔에서 **제한된 광고(Limited Ads)·비개인 맞춤 광고** 설정을 바꿨다면 2.2를 다시 본다.
- [ ] Firebase 콘솔에서 **Google 신호(Google signals)·데이터 공유 설정**을 켜면 Analytics 항목도 '공유'로 바뀔 수 있다 → 켜지 않는 것을 권장(지금 답은 '꺼짐' 기준).
- [ ] Analytics 데이터 보존 기간(2개월/14개월) — 개인정보처리방침 4항과 같은 값.
- [ ] 위 출처 페이지가 SDK 새 버전에서 바뀌지 않았는지(입력 직전 한 번 더 열람).

## 4. 결정 필요 (S1·사용자)
1. **Crashlytics를 동의 전에도 수집할지.** 지금: 배포 빌드는 동의와 상관없이 충돌 기록 수집, Analytics만 동의 뒤.
   - (가) 그대로 두고 방침에 "충돌 기록은 앱 안정성을 위해 동의와 관계없이 수집"이라고 밝힌다(이번 초안이 이렇게 씀).
   - (나) Crashlytics도 `ads.consent`에 묶는다(EEA는 동의 전 충돌을 못 봄) — 코드 몇 줄, platform 레인.
   - 권장: (가) — 충돌 기록에는 광고·추적 목적이 없고, EEA 이용자 비중이 작은 한국어 우선 출시라 품질 정보를 잃지 않는 편이 낫다. 단 사용자 결정.
2. **Android 자동 백업**: 지금 기본값(켜짐) → 기기를 바꿔도 진행이 복구되는 이점이 있다. 끄려면 `android:allowBackup="false"`. 권장: 켜 둔다(방침 1항에 한 줄로 밝힘).
