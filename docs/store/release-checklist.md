# 출시 체크리스트 (M5, Android)

- 2026-10-15, S5. 상태: ✅ 됨 · 🟡 초안/부분 · ⬜ 안 됨 · ❓ 결정 필요. 담당: 사람 · S1(main/통합) · 레인 이름.
- 순서는 대략 위→아래. 자세한 절차는 오른쪽 문서.

## A. 빌드·버전
| # | 항목 | 담당 | 상태 | 메모 / 문서 |
| --- | --- | --- | --- | --- |
| A1 | **버전 규칙**: `pubspec.yaml` `version: X.Y.Z+N` — N(versionCode)은 **업로드할 때마다 +1, 절대 재사용·감소 금지**(트랙 상관없이 앱 전체에서 하나). X.Y.Z는 사람 눈용: 비공개 테스트 0.9.x, 출시 1.0.0, 고친 빌드는 Z+1 | S1(pubspec은 shared) | 🟡 지금 0.1.0+1 | `android-release.md` 3절 |
| A2 | 패키지 ID 확정(한 번 올리면 못 바꿈) — 지금 임시 `repo.dot.pirate` | 사람 결정 → S1 | ❓ | ADR-0002 |
| A3 | targetSdk ≥ 36(2026-08-31부터 신규 앱·업데이트 필수) | — | ✅ Flutter 기본 compile/target 36, min 24 | [Google 문서](https://developer.android.com/google/play/requirements/target-sdk) |
| A4 | **화면 방향**: 세로 고정 `screenOrientation="portrait"` + `android:appCategory="game"`. Android 16(API 36)은 sw600dp 이상 화면에서 방향·크기 제한을 무시하지만 **게임은 예외**("Games (based on the android:appCategory flag)") → 태블릿·폴더블에서도 세로 유지. Flutter 쪽 `SystemChrome.setPreferredOrientations([portraitUp])`는 main.dart(S1) | platform(manifest) · S1(main.dart) | 🟡 manifest 반영(2026-10-15), main.dart 대기 | [Android 16 동작 변경](https://developer.android.com/about/versions/16/behavior-changes-16) · [appCategory](https://developer.android.com/guide/topics/manifest/application-element) |
| A5 | 업로드 키 생성 → `key.properties` | 사람 | ⬜ | `android-release.md` 1·2절 |
| A6 | `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols` | S1 | ✅ 키 없이 빌드 성공(54MB) | 기호 파일은 Crashlytics용 보관 |
| A7 | `dart run tool/release_check.dart` — 배포 aab에 운영자 표식 0회 | S1 | ✅ 2026-10-15 통과 | 업로드 전 매번 |
| A7b | **release apk 실기기 실행 1회** — `python -I -B docs/store/device/release_smoke.py`(설치·실행·10초 안에 앞 화면·크래시 0, 입력 없음). 2026-10-15 release가 실행 즉시 종료된 사고(R8이 WorkManager Room 클래스를 지움)를 빌드 검사는 못 잡았다 | S1·사람 | ✅ 수정 c881761 뒤 S24 통과 | `docs/store/device/release_smoke.py` |
| A8 | 실기기 확인 DEVICE_TEST.md 1~3절 | 사람 | 🟡 1차 설치 완료, 배치 v2 뒤 다시 | |

## B. 계정·연동
| # | 항목 | 담당 | 상태 | 문서 |
| --- | --- | --- | --- | --- |
| B1 | Play 개발자 계정(개인) 등록·본인 확인 | 사람 | ⬜ | |
| B2 | **비공개 테스트 12명 × 연속 14일 → 프로덕션 신청** | 사람 | ⬜ | `closed-test.md` |
| B3 | AdMob 앱 등록 → 실제 앱 ID·보상형 단위 ID 교체(지금 테스트 ID) | 사람 → platform | ⬜ | `admob.md` |
| B4 | AdMob 광고 콘텐츠 등급 상한을 등급 결과에 맞춤 + 민감 카테고리 차단 | 사람 | ⬜ | `content-rating.md` 3절 |
| B5 | Firebase 프로젝트 → `google-services.json` | 사람 | ⬜ | `firebase.md` |
| B6 | app-ads.txt (Blogger 리다이렉트 판정) | 사람 | 🟡 | `app-ads.md` |

## C. 스토어 등록정보
| # | 항목 | 담당 | 상태 | 문서 |
| --- | --- | --- | --- | --- |
| C1 | 앱 이름 ko `해적도트 원정대` / en | 사람 | 🟡 ko 확정, en 대기 | `listing.*.md` |
| C2 | 간단한 설명·자세한 설명 ko/en | platform 초안 → 사람 승인 | 🟡 | `listing.*.md` |
| C3 | 앱 아이콘 512 | platform | ✅ `build/store/icon-512.png`(apply_icons) | `icon.md` |
| C4 | 그래픽 이미지 1024×500 | platform | ✅ 초안 `build/store/feature_graphic.png` | `feature_graphic.py` |
| C5 | 휴대전화 스크린샷 8장 ko/en | platform(자동) → 사람 승인·캡션 | 🟡 배치 v2 머지 뒤 다시 굽기 | `listing.ko.md` "자동 굽기" |
| C6 | 개발자 연락처(이메일·웹사이트) | — | ✅ | `listing.ko.md` |
| C7 | 개인정보처리방침 블로그 게시 → URL 입력 | 사람 | 🟡 초안, 보존 기간 미정 | `privacy-policy.*.md` |

## D. 앱 콘텐츠(정책) 선언
| # | 항목 | 담당 | 상태 | 문서 |
| --- | --- | --- | --- | --- |
| D1 | 광고 포함 = 예 | 사람 | ⬜ | |
| D2 | **광고 ID 선언 = 사용함**(병합 manifest에 `com.google.android.gms.permission.AD_ID` 있음 — AdMob SDK가 넣음). 목적: 광고(+ Firebase Analytics를 켜면 분석 — 콘솔 선택지 확인) | 사람 | ⬜ | 2026-10-15 병합 manifest 확인 |
| D3 | 데이터 보안 양식 | 사람 | 🟡 대응표 있음 | `privacy-policy.ko.md` "Play 데이터 보안 양식 대응" |
| D4 | 콘텐츠 등급(IARC) 설문 | 사람 | 🟡 답변 초안 | `content-rating.md` |
| D5 | **타깃 연령: 13세 이상만**(13세 미만 포함 시 가족 정책 적용) — 스토어 문구에 아동 겨냥 표현 없음 확인함 | 사람 결정 | ❓ 추천 13+ | `content-rating.md` 5절 |
| D6 | 앱 접근(로그인 없음) · 뉴스 앱 아님 · 정부 앱 아님 · 금융 기능 없음 · 건강 기능 없음 | 사람 | ⬜ | |
| D7 | 권한 확인: 알림(POST_NOTIFICATIONS)·부팅 후 예약 복구(RECEIVE_BOOT_COMPLETED)·진동·인터넷. **FOREGROUND_SERVICE**가 병합 manifest에 있음(`androidx.work:work-runtime 2.7.0`이 넣음 — 다른 라이브러리 의존). 콘솔이 포그라운드 서비스 선언을 요구하는지 확인(타입 없는 기본 권한이라 대상 아닐 가능성 — 미확인) | 사람 확인 → platform | ⬜ | manifest-merger-release-report |
| D8 | 정확한 알람 권한 미사용 확인(알림은 근사 예약) | platform | ✅ manifest에 SCHEDULE_EXACT_ALARM 없음 | |

## E. 출시
| # | 항목 | 담당 | 상태 |
| --- | --- | --- | --- |
| E1 | 국가: 처음엔 한국(+영어권?) — EU 포함 시 UMP 동의 창·개인정보 옵션 버튼 필수(구현됨, 실기기 확인 필요) | 사람 결정 | ❓ |
| E2 | 단계적 출시 비율(예: 20% → 100%) · Crashlytics 지켜보기 | 사람 | ⬜ |
| E3 | 출시 노트 ko/en | platform 초안 | ⬜ |

## 사람이 먼저 정할 것 (막혀 있는 것)
A2 패키지 ID · A4 화면 고정(+태블릿) · C1 영문 이름 · D5 타깃 연령 · E1 국가 — 이 다섯이 정해지면 나머지는 순서대로 진행된다.
