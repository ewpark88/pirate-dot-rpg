# Store listing — English (draft)

- Status: draft (2026-10-14, S5 · updated 2026-10-18 for the redesign — HD monsters, no boss timer, Break, chain lightning, collecting) · Source: design doc ch. 1 & 4 · Korean name confirmed: 해적도트 원정대. **English name is a proposal awaiting confirmation.** Package ID before M5 (ADR-0002).
- Google Play limits: title 30 · short description 80 · full description 4000 characters.
- Rules (design 9, 4.9): no ranking claims ("#1"), gacha only as "odds disclosed", nothing that contradicts the no-fatigue rules ("log in every day!").

## Title (30)
Pirate Dot Expedition  ← proposal, awaiting confirmation (확정 대기)

## Short description (≤80)
Blast monster swarms in one shot! Pirate idle RPG: 42 bosses, 40 crew to collect

## Full description
⚓ Two buttons. Huge explosions.
Upgrade your pirate ship and summon your crew. Battles, skills and sailing are all automatic.
Sweep away swarms of cute cartoon sea and sky monsters with cannons and area skills.

🔥 Hack-and-slash, one blast at a time
- Area attacks pop whole swarms at once — Double, Triple, Massacre!, Pirate King!
- Every kill charges the Fever gauge — when it's full, your captain's opening strike kicks off Fever and monsters swarm in 2.5× thicker
- Chain lightning that jumps from foe to foe, skipping stones, lasers and ring barrages
- Hit-stop, screen shake and coin fountains — the battlefield keeps exploding even when you don't touch it

🏴‍☠️ A ship that visibly grows
- Upgrade 5 parts: Cannon, Hull, Sail, Crow's Nest and Cargo Hold — your ship changes as you go
- Automatic promotions: Dinghy → Sloop → Pirate Warship → Ghost Ship
- Every 25 levels, the effect doubles

👥 Collect 40 crew members, 11 attack styles
- Direct, Lob, Pierce, Skip, Underwater, Air, Assault, Shock, Laser, Ring barrage, Cluster bomb — each with its own area shape and effects
- When a new mate joins, a card shows their role and how they fight · preview any crew member's attack before you deploy them
- Codex rewards at 5, 10, 20, 30 and 40 crew — merge matching cards to raise a crew member from Common all the way to Mythic
- All summon odds and the pity rule (Hero or better within 50 pulls) are shown in game

🌊 A long voyage across six seas
- Coral Reef → Storm Sea → Glacier Sea → Volcanic Sea → The Abyss → Phantom Sea, each with new monsters and a sea boss
- 42 bosses, including screen-filling giants — evade, armor, regen, reflect, enrage, escort and dash traits each call for a different plan
- No time limit on boss fights: keep fighting as long as your ship holds. Keep up the pressure for a BREAK — the boss stalls and takes extra damage
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
2. "FEVER! Here comes the swarm"
3. "42 bosses, no time limit"
4. "Lightning jumps, swarms pop"
5. "Collect all 40 crew"
6. "See it, then pick your crew"
7. "Merge your way to Mythic"
8. "Rebirth and set sail stronger"

## Contact & website
- Developer name: 박은우 (romanized spelling for the English listing: to be confirmed — 확인 필요)
- Developer email: repo.dev88@gmail.com (public on the store)
- Website: https://rich-fire.blogspot.com/ — AdMob looks for app-ads.txt at this domain's root (open questions in `docs/store/app-ads.md`)
- Privacy policy URL: a page on the same blog, `https://rich-fire.blogspot.com/p/<…>.html` — fill in after publishing (`privacy-policy.en.md`)
