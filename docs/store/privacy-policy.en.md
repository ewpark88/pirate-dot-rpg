# Privacy Policy — 해적도트 원정대 / Pirate Dot Expedition (draft; English name awaiting confirmation)

> Draft (2026-10-14, S5 · updated 2026-10-18: Google's published SDK data, rewarded ads, analytics events, crash-report consent, auto backup). Published as a page on https://rich-fire.blogspot.com/ by a person (`app-ads.md` §5). Fill in `<…>`. Not legal advice — have a person review before release.
> Mirrors what the app actually does: no accounts or servers, saves stay on the device, ads via AdMob (+UMP), analytics via Firebase Analytics & Crashlytics, local notifications.

Effective date: `<publish date>` · Developer: 박은우 `<romanized name — to be confirmed>` · Contact: repo.dev88@gmail.com

## 1. What we don't collect
- There is no sign-up or login. We do not collect your name, email, phone number, location, contacts or photos.
- Your game progress (save data) is stored **on your device** and is never sent to us. Uninstalling the app deletes it.
  If Android auto backup is on, your save may be included in **your own Google account backup** and restored on a new device (an Android feature; we cannot see it).

## 2. Information processed by third-party services
| Service (provider) | Purpose | Information |
| --- | --- | --- |
| Google AdMob (Google) | Showing and measuring rewarded ads, fraud prevention | IP address (may be used to estimate approximate location), advertising ID and app set ID, device/OS and diagnostic info (such as launch time), ad interactions (launches, taps, views) |
| Google UMP (Google) | Collecting consent for ads and analytics (EEA etc.) | Your consent choices |
| Firebase Analytics (Google) | Understanding drop-off and improving the game | Screen views, last screen and stage seen, game events (bounty hunt start/clear/fail, codex discoveries — boss name, tier and reward amounts), app instance ID, advertising ID, approximate location derived from a masked IP address, device/OS info |
| Firebase Crashlytics (Google) | Fixing bugs | Crash reports (stack traces), screen at the time of the crash, device/OS info, installation ID |

- We do not try to identify you from this information, and we do not sell it.
- How Google uses data: https://policies.google.com/technologies/partner-sites
- All ads are **rewarded ads** that you choose to watch by tapping a reward button. There are no real-money purchases.
- Users in the EEA, UK and Switzerland see a consent form on first launch. **No ads are requested and no Analytics data is collected before consent.**
  You can change your choice at any time under "Privacy options" in the game settings.
- **Crash reports (Crashlytics) are collected regardless of consent to keep the app stable** (never used for ads or tracking). `<pending decision — data-safety.md §4: remove this line if crash reports are tied to consent>`
- Google processes this information as our service provider; AdMob shares information with Google's ad network to serve ads.

## 3. Device permissions
- **Notifications**: at most one notification a day, when your offline reward is full. It is scheduled locally on the device, not sent from a server. Turn it off in the game settings or in your device settings.
- **Internet**: used only for ads and analytics. The game works offline.
- You can reset or delete your advertising ID in your device settings (Android: Settings > Privacy > Ads).

## 4. Retention and deletion
- Save data: on your device until you uninstall the app.
- Analytics: deleted automatically after the Firebase retention period `<undecided — 2 or 14 months, awaiting the owner's decision>`. Crashlytics crash reports: 90 days.
- To request deletion of analytics data, email repo.dev88@gmail.com and we will help you find your app instance ID.

## 5. Children
This game is not directed at children under 13, and we do not knowingly collect personal information from children.

## 6. Changes
We will post any changes on this page and update the effective date. Significant changes will also be announced in the game.

## 7. Contact
repo.dev88@gmail.com
