# 사람 입력·계정이 필요한 일 (platform, 모아 보기)

- 갱신: 2026-10-15, S5. 세부 절차는 각 문서. 끝나면 [x]로 바꾸고 날짜를 적는다.

## 결정 (사용자)
- [ ] 영문 게임 이름 확정 — 제안 `Pirate Dot Expedition` (`listing.en.md`). 확정되면 `android/app/src/main/res/values/strings.xml`의 `app_name`도.
- [ ] 영문 개발자명 표기 (박은우 → 로마자) — `listing.en.md`
- [ ] Firebase Analytics 데이터 보존 기간 2개월/14개월 — `privacy-policy.ko/en.md`
- [ ] 패키지 ID (ADR-0002, M5 전) — 지금 `applicationId`는 임시

## 계정·키 (사람이 직접)
- [ ] Firebase 프로젝트 → `apps/game/android/app/google-services.json` 넣기(커밋 안 함) — `firebase.md`. 없으면 분석은 자동 no-op.
- [ ] AdMob 앱 등록 → 실제 앱 ID·보상형 단위 ID (지금 테스트 ID) — `admob.md`
- [ ] AdMob 콘솔에서 app-ads.txt 판정 (Blogger `/app-ads.txt` → `/ads.txt` 리다이렉트를 인정하는지) — `app-ads.md` 2·3절
- [ ] 업로드 키 생성 → `android/key.properties` (커밋 안 함) — `android-release.md`
- [ ] Play Console 앱 등록·내부 테스트 트랙 — `android-release.md`
- [ ] 개인정보처리방침 블로그 게시(ko/en) — `app-ads.md` 5절

## 그림·캡처
- [ ] 아이콘 원본 격자 PNG (`foreground` 54·`legacy` 24 필수, 나머지 선택) + 배경색 — `icon.md` 4절. 오면 `apply_icons.py` 한 번.
- [ ] 스크린샷 8장 · 그래픽 이미지 1024×500 — `listing.ko.md`

## 실기기 확인 (S1 main.dart 연결 뒤)
- [ ] 테스트 광고 로드·시청·보상, UMP 폼(EU 아니면 안 뜸), 개인정보 옵션 버튼
- [ ] 오프라인 가득 알림 (운영자 "알림 10초 뒤" — 요청서 `platform-operator-test`), 권한 1회
- [ ] 소리(효과음 4개 겹침 한도), 저장·복원(백그라운드 → 강제 종료 → 재실행)
- [ ] 런처 이름 ko/en, (아이콘 적용 뒤) 원형·사각·테마 아이콘·스플래시 12+/11 이하
