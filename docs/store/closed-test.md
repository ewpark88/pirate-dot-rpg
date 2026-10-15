# 비공개 테스트 (Play 신규 개인 개발자 계정 요건)

- 2026-10-15 확인, S5. 출처: Play Console 고객센터 "신규 개인 개발자 계정의 앱 테스트 요건"
  https://support.google.com/googleplay/android-developer/answer/14151465 (페이지에 수정일 표기 없음, 2026-10-15 열람).
  **콘솔에 들어가면 그 시점 요건을 다시 본다** — 이 규칙은 2023-11 도입 뒤 테스터 수가 바뀐 적 있다(처음 20명 → 지금 12명, 바뀐 날짜는 공식 문서로 확인 못 함).

## 1. 요건 (공식 문서 인용)
- 대상: "personal developer accounts created after November 13, 2023" — 우리 계정을 새로 만들면 해당.
- **테스터 12명 이상**이 비공개 테스트에 참여(opt-in)한 상태로 **연속 14일**. "the 14 days must be consecutive".
- 14일을 못 채우고 나간 테스터는 세지 않는다: "Testers who opt in, test for fewer than 14 days, and then opt out do not count toward the requirement."
- 프로덕션 신청 때도 12명 이상 참여 중이어야 한다: "At least 12 testers must be opted in to your closed test when you apply for production access."
- 그 뒤 콘솔 대시보드에서 **프로덕션 액세스 신청**. 질문 3묶음: "About your closed test" · "About your app/game" · "About your production readiness".
  비공개 테스트 묶음에서 "Summarize the feedback received from testers and describe how feedback was collected"를 묻는다 → **피드백 기록을 남겨야 한다**(3절).
- 심사: "Review usually takes seven days or less, but can occasionally take longer."
- 그 전엔 프로덕션·사전 등록이 막혀 있다.
- 공식 문서에 없는 것(제3자 글에만 있음, 믿지 않음): 조직 계정 면제, "12명 아래로 내려가면 0일부터 다시". → 안전하게 **12명 아래로 절대 안 내려가게** 운영한다.

## 2. 계획
| 단계 | 언제 | 할 일 | 담당 |
| --- | --- | --- | --- |
| 0 | 테스트 전 | 계정 등록·본인 확인, 앱 만들기, 내부 테스트 트랙에 aab 1회 올려 설치 확인(`android-release.md`) | 사람 |
| 1 | D-7 | **테스터 18~20명 모집**(여유 6~8명 — 중간 이탈 대비). Google 계정 Gmail 목록 받기 | 사람 |
| 2 | D0 | 비공개 테스트 트랙(이메일 목록) 만들기 → aab 업로드 → 참여 링크 공유 → **각자 링크에서 '테스터 되기' + 스토어에서 설치까지** 확인(참여만 하고 설치 안 하면 쓸모가 줄고, 피드백도 없다) | 사람 |
| 3 | D0~D14 | 매일 1번 콘솔에서 참여 수 확인(12명 + 여유). 2~3일마다 새 빌드(버그 수정) 올려 테스트가 살아 있음을 보이기. 버전 코드 +1 규칙(`release-checklist.md`) | 사람 + S1 |
| 4 | D7 | 중간 설문(아래 3절) | 사람 |
| 5 | D14+ | 최종 설문 → 피드백 요약 작성 → 프로덕션 액세스 신청 | 사람(요약 초안은 S5가 설문 결과로 작성 가능) |
| 6 | 신청 후 ~7일 | 심사 대기. 거절되면 이유 읽고 테스트 더 | 사람 |

**모집 방법**(돈 안 드는 순):
1. 지인·가족(안드로이드 폰 + Google 계정) — 가장 확실. 10명 목표.
2. 블로그(https://rich-fire.blogspot.com/)에 테스터 모집 글 + 신청 폼(Google Forms: 이름·Gmail·기기).
3. 개발자 커뮤니티의 "테스터 품앗이" 게시판(서로 14일 테스트해 주기). 상대 앱도 14일 깔아 둬야 한다.
4. 유료 테스터 대행 서비스는 쓰지 않는다 — 피드백 품질이 낮고 정책 위반 소지(확인 안 됨)가 있어 권하지 않음.

## 3. 피드백 받는 경로 (신청서 "how feedback was collected"에 그대로 쓴다)
- **Google Forms 설문 2회**(D7 중간, D14 최종) — 문항 초안:
  1. 기기 이름·Android 버전 2. 하루에 몇 번 켰나 3. 가장 재미있던 순간 4. 답답하거나 이해 안 된 곳 5. 버그(화면 캡처 첨부)
  6. 광고 버튼을 눌러 봤나·불편했나 7. 알림이 왔나·적당했나 8. 계속 하고 싶은가(1~5)
- **Play 비공개 피드백**: 테스터가 스토어 앱 페이지에서 남기는 비공개 의견(콘솔 "테스터 피드백"에서 봄).
- **Crashlytics**(google-services.json 넣은 뒤): 비정상 종료 자동 수집 — 신청서에 "충돌 N건 → 수정 빌드 M개"로 적는다.
- 기록: `docs/store/closed-test-log.md`(새로 만들 것)에 날짜·참여 수·받은 피드백·고친 빌드를 한 줄씩 → 신청서 요약의 근거.

## 4. 테스트 중 확인할 것 (실기기 많을수록 좋은 항목)
- DEVICE_TEST.md 3절(광고·알림·저장·이름) 항목을 테스터 기기 종류별로.
- 저사양 기기 성능(부하 장면 p95), 알림 권한 흐름(Android 13+), 오프라인 8시간 보상.
- UMP 동의 창은 EU 테스터가 있으면 확인(없으면 VPN으로는 확인 불가할 수 있음 — 미확인).
