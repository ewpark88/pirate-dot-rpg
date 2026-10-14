# app-ads.txt — 개발자 웹사이트 https://rich-fire.blogspot.com/ (Blogger)

AdMob이 "이 앱의 광고 인벤토리를 팔아도 되는 판매자"를 확인하는 파일(설계서 9.2). AdMob은 **Play 스토어 등록정보의 개발자 웹사이트** 도메인 루트에서
`/app-ads.txt`를 찾는다. 웹사이트는 사용자 결정(2026-10-14): `https://rich-fire.blogspot.com/`.

## 1. 2026-10-14 실제로 확인한 것 (curl, S5)
| 요청 | 결과 |
| --- | --- |
| `https://rich-fire.blogspot.com/app-ads.txt` | **301 → `/ads.txt`** (같은 호스트) |
| `http://rich-fire.blogspot.com/app-ads.txt` | 301 → https 같은 경로 → 301 → `/ads.txt` |
| `https://rich-fire.blogspot.com/ads.txt` | 200 `text/plain` · 내용 `google.com, pub-8353634332299342, DIRECT, f08c47fec0942fa0` |
| 없는 경로(`/nonexistent-xyz.txt`) | 404 — 위 리다이렉트는 Blogger가 일부러 하는 동작 |
| `robots.txt` | `Disallow: /search`, `/share-widget`만. `Mediapartners-Google` 전체 허용 → 크롤러를 막지 않음 |

즉 **Blogger에는 app-ads.txt 전용 설정이 없지만(검색으로 찾은 범위), `/app-ads.txt`를 `/ads.txt`로 보내고, `/ads.txt` 내용은
설정 > 수익 창출 > "맞춤 ads.txt 사용"으로 바꿀 수 있다.**

## 2. 확인 필요 (추측으로 단정하지 않음)
1. **AdMob 크롤러가 경로가 바뀌는 리다이렉트(`/app-ads.txt` → `/ads.txt`)를 따라가 인정하는가.**
   AdMob 도움말은 "루트 도메인이 app-ads.txt를 반환하거나 그것으로 리다이렉트해야 한다", "도메인 → www 리다이렉트는 흔하다", "200이어야 한다"까지만 말하고,
   상태 코드 종류나 경로 변경은 다루지 않는다. → 실제 판정은 **AdMob 콘솔 → 앱 → app-ads.txt 탭**(크롤링 최대 24시간)에서만 확인된다.
2. **`pub-8353634332299342`(지금 ads.txt에 있는 값, 아마 AdSense)가 AdMob 게시자 ID와 같은가.**
   같은 Google 계정의 AdSense·AdMob은 게시자 ID를 공유하는 경우가 있지만 여기서는 확인하지 못했다 → AdMob 콘솔 → 설정 → 계정 정보의 게시자 ID와 비교.
3. `rich-fire.blogspot.com`이 "루트 도메인"으로 취급되는가(`blogspot.com`은 공용 접미사 목록에 있어 하위 도메인마다 독립 사이트로 보는 것이 일반적이지만, AdMob 문서에서 명시는 못 찾음).

## 3. 절차 (M5, AdMob 계정·Play 등록 뒤 — 사람)
1. AdMob 콘솔 → 설정 → 계정 정보 → **게시자 ID** 확인.
2. Blogger → 설정 → 수익 창출 → **맞춤 ads.txt 사용** 켜기 → 내용:
   ```
   google.com, pub-<AdMob 게시자 ID>, DIRECT, f08c47fec0942fa0
   ```
   - 게시자 ID가 지금 줄(`pub-8353634332299342`)과 같으면 **이미 들어 있어서 할 일 없음**.
   - 다르면 지금 줄을 **지우지 말고** 아래에 한 줄 추가(블로그 AdSense 광고가 끊기지 않게).
   - 맞춤 ads.txt를 켜면 Blogger가 자동으로 넣던 줄이 사라질 수 있다 → 켜기 전에 지금 내용(위 표)을 그대로 먼저 붙여 넣는다.
3. 확인: 브라우저로 `https://rich-fire.blogspot.com/app-ads.txt` → `/ads.txt`로 넘어가 새 줄이 보이는지.
4. Play Console → 스토어 등록정보 → 연락처 세부정보 → 웹사이트 = `https://rich-fire.blogspot.com/` (끝 슬래시 포함 여부 무관, 도메인이 같아야 함).
5. AdMob → 앱 → app-ads.txt 탭에서 24시간 뒤 상태 확인. **"찾을 수 없음/승인되지 않음"이면 2.1이 안 되는 것** → 4절 대안.
- 지금 쓰는 테스트 ID(`ca-app-pub-3940256099942544`)는 넣지 않는다(Google 소유, 의미 없음).

## 4. 안 될 때 대안 (Play의 개발자 웹사이트를 다른 도메인으로)
개발자 웹사이트와 개인정보처리방침 URL은 **다른 주소여도 된다** — 개인정보처리방침은 Blogger 페이지에 그대로 두고 웹사이트만 바꿀 수 있다.
| 대안 | 비용 | 루트에 파일 | 비고 |
| --- | --- | --- | --- |
| Firebase Hosting 기본 도메인 `https://<프로젝트>.web.app` | 무료(Spark) | 가능 | AdMob 공식 문서가 루트에 둘 수 없을 때의 방법으로 소개. Firebase 프로젝트는 Analytics용으로 어차피 만든다(`firebase.md`) |
| GitHub Pages **사용자** 사이트 `https://<아이디>.github.io` | 무료 | 가능(저장소 루트) | 프로젝트 사이트 `…github.io/<저장소>/`는 루트가 아니라 안 됨 |
| 커스텀 도메인 | 연 1~2만 원 | 가능 | 설계서 "비용 0원" 원칙에 어긋남 — 마지막 수단 |
대안으로 바꾸면 Play 웹사이트를 그 주소로 바꾸고 3절 5번을 다시 확인한다.

## 5. 개인정보처리방침 게시 (같은 블로그)
- Blogger → 페이지 → 새 페이지 "개인정보처리방침" → `privacy-policy.ko.md` 본문(사람용 표 제외), 영어는 별도 페이지 `Privacy Policy`.
- 주소는 `https://rich-fire.blogspot.com/p/<제목에서 만든 이름>.html` 형태 — 게시 뒤 실제 주소를 Play Console "개인정보처리방침" 칸과 `listing.*.md`에 적는다.

출처: [AdMob app-ads.txt 문제 해결](https://support.google.com/admob/answer/9679128), [AdMob 개발자 문서 app-ads.txt](https://developers.google.com/admob/android/next-gen/app-ads),
[Blogger 블로그에 광고 게재(맞춤 ads.txt)](https://support.google.com/blogger/answer/1269077?hl=en), [Ezoic: Blogger는 ads.txt 리다이렉트를 직접 설정할 수 없음](https://support.ezoic.com/kb/article/609)
