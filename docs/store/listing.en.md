# Store listing — English (draft)

- Status: draft (2026-10-14, S5) · Source: design doc ch. 1 & 4 · Korean name confirmed: 해적도트 원정대. **English name is a proposal awaiting confirmation.** Package ID before M5 (ADR-0002).
- Google Play limits: title 30 · short description 80 · full description 4000 characters.
- Rules (design 9, 4.9): no ranking claims ("#1"), gacha only as "odds disclosed", nothing that contradicts the no-fatigue rules ("log in every day!").

## Title (30)
Pirate Dot Expedition  ← proposal, awaiting confirmation (확정 대기)

## Short description (≤80)
Blast whole monster swarms in one shot! Pixel pirate idle RPG. Upgrade & summon.

## Full description
⚓ Two buttons. Huge explosions.
Upgrade your pirate ship and summon your crew. Battles, skills and sailing are all automatic.
Sweep away swarms of sea and sky monsters with cannons and area skills.

🔥 Hack-and-slash, one blast at a time
- Area attacks pop whole swarms at once — Double, Triple, Massacre!, Pirate King!
- Every kill charges the Fever gauge; when it's full, your captain's opening strike sweeps the entire screen and Fever begins
- Hit-stop, screen shake and coin fountains — the battlefield keeps exploding even when you don't touch it

🏴‍☠️ A ship that visibly grows
- Upgrade 5 parts: Cannon, Hull, Sail, Crow's Nest and Cargo Hold — your ship changes as you go
- Automatic promotions: Dinghy → Sloop → Pirate Warship → Ghost Ship
- Every 25 levels, the effect doubles

👥 40 crew members, 8 attack styles
- Skipping shots, throws, air strikes, boarding charges — each style has its own area shape and effects
- Merge matching cards to raise a crew member from Common all the way to Mythic
- All summon odds and the pity rule (Hero or better within 50 pulls) are shown in game

🌊 A long voyage across six seas
- Coral Reef → Storm Sea → Glacier Sea → Volcanic Sea → The Abyss → Phantom Sea, each with new monsters and a sea boss
- Rebirth with the Treasure Map and set sail stronger — catch up to your old record in about 5 minutes
- Crew codex, 4 daily quests, attendance rewards

😌 No fatigue
- Up to 8 hours of gold piles up while the app is closed
- Miss a day of attendance? Your streak doesn't reset. No rewards that vanish if you miss them
- Ads are never forced — watch only when you want, and the bonus is always shown as a number
- Auto-upgrade, power-save mode, and toggles for shake, flash and vibration
- At most one notification a day, only when your offline reward is full (can be turned off)

Korean and English · Playable offline (ads need a connection)

## Category & tags
- Category: Games > Role Playing (alt: Casual)
- Tags: Idle, Pixel art, Pirates, Offline, Single player
- Content rating (expected IARC): fantasy violence (no blood), no user interaction (before leaderboards), no real-money gambling → Everyone to 12+
- Contains ads: yes · In-app purchases: none (phase 1)

## Graphics
Names above match the in-game English strings (`parts/*.en.arb`: `shipTier*`, `battleRegion*`, `battleCombo*`, `uiFeverBig`, `uiRebirthTitle`).
Same assets and screenshot order as `listing.ko.md`, with English UI (set the device or in-game language to English) and these captions:
1. "Blast the whole swarm!"
2. "FEVER! A screen-wide opening strike"
3. "Upgrade it and watch your ship change"
4. "Summon 40 crew members"
5. "Merge your way to Mythic"
6. "Six seas, six sea bosses"
7. "8 hours of loot while you're away"
8. "Rebirth and set sail stronger"

## Contact & website
- Developer name: 박은우 (romanized spelling for the English listing: to be confirmed — 확인 필요)
- Developer email: repo.dev88@gmail.com (public on the store)
- Website: https://rich-fire.blogspot.com/ — AdMob looks for app-ads.txt at this domain's root (open questions in `docs/store/app-ads.md`)
- Privacy policy URL: a page on the same blog, `https://rich-fire.blogspot.com/p/<…>.html` — fill in after publishing (`privacy-policy.en.md`)
