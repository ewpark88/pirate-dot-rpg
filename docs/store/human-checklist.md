# 출시 전 사람이 할 일 — 한 장 (순서대로)

- 2026-10-18 · S5 · 요청: S1. 끝나면 `[x]`와 날짜. 자세한 절차는 괄호 안 문서. 예상 시간은 처음 하는 기준.
- 준비물: 개발자 Google 계정(Play 콘솔·AdMob·Firebase 같은 계정 권장), 폰(실기기), PC의 `apps/game` 폴더.

## 0. 먼저 정할 것 (5분)
- [ ] 영문 앱 이름(제안 `Pirate Dot Expedition`) · 영문 개발자명(로마자) · 패키지 ID(지금 임시 — 한 번 올리면 못 바꿈) (`human-inputs.md` 결정)

## 1. 키·설정 파일 (40분)
| 순서 | 할 일 | 어디서 클릭 | 시간 |
| --- | --- | --- | --- |
| 1 | 업로드 키 만들기 → `apps/game/android/key.properties`(커밋 안 함) | PC 명령(`android-release.md` 2절) | 10분 |
| 2 | Firebase 프로젝트 → Android 앱 추가(패키지 ID) → `google-services.json`을 `apps/game/android/app/`에 | console.firebase.google.com → 프로젝트 추가 → ⚙ 프로젝트 설정 → 내 앱 → Android | 15분 |
| 3 | AdMob 앱 등록 → 앱 ID·보상형 광고 단위 ID 받아 넣기(지금 테스트 ID) | admob.google.com → 앱 → 앱 추가 → 광고 단위 → 보상형 (`admob.md`) | 15분 |

## 2. Play 콘솔 앱 만들기·양식 (1시간 30분)
| 순서 | 할 일 | 어디서 클릭 | 시간 |
| --- | --- | --- | --- |
| 4 | 앱 만들기(이름·기본 언어 한국어·게임·무료) | play.google.com/console → 앱 만들기 | 5분 |
| 5 | 개인정보처리방침 블로그 게시(ko/en — 알림 문장 바뀐 최신본) → URL 입력 | Blogger → 페이지 / 콘솔 → 정책 → 앱 콘텐츠 → 개인정보처리방침 (`privacy-policy.ko.md`) | 15분 |
| 6 | 데이터 보안 양식 | 콘솔 → 정책 → 앱 콘텐츠 → 데이터 보안 (`data-safety.md` — 입력 직전 3절 4개 확인) | 25분 |
| 7 | 콘텐츠 등급 설문(IARC) · 타깃 연령 13세 이상 · 광고 포함 '예' | 콘솔 → 앱 콘텐츠 → 콘텐츠 등급 / 타깃층 / 광고 (`content-rating.md`) | 15분 |
| 8 | 스토어 등록정보(짧은·긴 설명 ko/en, 아이콘·그래픽 이미지·스크린샷) | 콘솔 → 성장 → 기본 스토어 등록정보 (`listing.ko.md`·`listing.en.md`, 이미지는 `build/store/`) | 20분 |
| 9 | 인앱 상품 18개 만들기(ID·가격) — 아래 표 | 콘솔 → 수익 창출 → 제품 → 인앱 상품 / 구독 | 30분 |

### 9의 상품 ID·가격 (iap.json · `docs/specs/economy-iap.md`)
| 종류 | ID | 가격(원 / $) |
| --- | --- | --- |
| 구독 30일 | `no_ads_30d` · `speed_30d` | 3,900 / 2.99 |
| 구독 30일 | `gem_monthly` | 5,900 / 4.99 |
| 구독(시즌 30일) | `voyage_pass` | 9,900 / 7.99 |
| 비소모 | `no_ads` · `speed` | 12,000 / 9.99 |
| 비소모 | `captain_pack` | 19,000 / 14.99 |
| 비소모(계정당 1회) | `starter_pack` | 2,500 / 1.99 |
| 비소모 | `skin_golden_galleon` · `skin_jolly_flag` · `skin_coral_yacht` | 3,900 / 2.99 |
| 비소모 | `skin_bundle` | 7,900 / 5.99 |
| 비소모 | `offline_12h` | 5,900 / 4.99 |
| 소모 | `gem_120` · `gem_650` · `gem_1400` · `gem_4200` · `gem_9000` | 1,200 · 5,900 · 12,000 · 33,000 · 69,000 / 0.99 · 4.99 · 9.99 · 24.99 · 49.99 |
- ID는 표와 **글자 하나까지 같게**(다르면 앱이 상품을 못 찾는다). 구독은 '기본 요금제' 30일·자동 갱신. 상품은 '활성'으로.

## 3. 시험 업로드 (40분)
| 순서 | 할 일 | 어디서 클릭 | 시간 |
| --- | --- | --- | --- |
| 10 | 배포 빌드(aab) 만들기 — S1에 요청하거나 `flutter build appbundle` | PC (`android-release.md` 3절, `release-checklist.md`) | 10분 |
| 11 | 내부 테스트 트랙에 aab 올리기 · 테스터(본인 Gmail) 추가 · 참여 링크로 폰에 설치 | 콘솔 → 테스트 → 내부 테스트 → 새 버전 (`closed-test.md`) | 15분 |
| 12 | 라이선스 테스트 계정 등록(본인 Gmail) — 결제가 '테스트 카드'로 무료 | 콘솔 → 설정(⚙) → 라이선스 테스트 | 5분 |
| 13 | 폰에서 확인: 광고 보상 1번 · 젬 120 구매 1번(테스트 카드) · 광고 제거 구매 → 광고 없이 보상 | 폰 | 10분 |

## 4. 오류 대비 (15분)
| 순서 | 할 일 | 어디서 클릭 | 시간 |
| --- | --- | --- | --- |
| 14 | Crashlytics 테스트 크래시 1건 확인(내부 테스트 빌드에서 — 운영자 빌드 아님) | console.firebase.google.com → Crashlytics (`crash-anr.md` 4절) | 10분 |
| 15 | 바이탈 알림 켜기(비정상 종료·ANR '나쁨' 기준) | Play 콘솔 → 품질 → Android vitals → 알림 설정 | 3분 |
| 16 | AdMob 광고 콘텐츠 등급 상한(G/PG)·민감 카테고리 차단 · app-ads.txt 판정 | AdMob → 차단 관리 / 앱 → app-ads.txt (`content-rating.md` 3절·`app-ads.md`) | 5분 |

## 5. 출시
- [ ] 비공개 테스트(12명 × 14일 — 개인 개발자 신규 계정 규칙) → 프로덕션 신청 (`closed-test.md`)
- 합계: 처음이면 약 3~4시간(테스트 기간 제외).
