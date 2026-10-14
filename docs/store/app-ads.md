# app-ads.txt (초안 — 사람이 게시)

AdMob이 "이 앱의 광고 인벤토리를 판매해도 되는 판매자"를 확인하는 파일. 없으면 광고 수익이 제한될 수 있다(설계서 9.2).

## 파일 내용 (AdMob 계정을 만든 뒤 — M5)
```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```
- `pub-XXXXXXXXXXXXXXXX`: AdMob 콘솔 → 설정 → 계정 정보 → **게시자 ID**. 앱 ID(`ca-app-pub-…~…`)가 아니다.
- `f08c47fec0942fa0`: Google의 인증 기관 ID(고정값).
- **지금 쓰는 테스트 ID(`ca-app-pub-3940256099942544`)는 넣지 않는다** — Google 소유라 의미 없다.

## 게시 위치 (GitHub Pages)
1. Pages 저장소(예: `<사용자>.github.io` 또는 별도 저장소의 Pages)의 **루트**에 `app-ads.txt`. 하위 폴더는 인식되지 않는다.
   - 사용자 사이트 `https://<사용자>.github.io/app-ads.txt` 처럼 **도메인 루트**여야 한다. 프로젝트 사이트(`…github.io/<저장소>/`)는 루트가 아니라서 안 된다 → 사용자 사이트나 커스텀 도메인을 쓴다.
2. 같은 사이트에 `privacy/index.html`(← `privacy-policy.ko.md`·`.en.md`를 한 페이지에 두 언어로, 또는 `/privacy/en/`).
3. Play Console → 스토어 등록정보 → 연락처 세부정보 → **웹사이트**에 같은 도메인(`https://<사용자>.github.io`)을 넣는다. AdMob은 이 주소 루트에서 app-ads.txt를 찾는다.
4. 확인: AdMob → 앱 → app-ads.txt 탭. 크롤링에 최대 24시간.
