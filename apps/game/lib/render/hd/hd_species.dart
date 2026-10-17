import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/angler.dart';
import 'package:pirate_dot/render/hd/species/blaze_pirate.dart';
import 'package:pirate_dot/render/hd/species/boss_cephalo.dart';
import 'package:pirate_dot/render/hd/species/boss_coral2.dart';
import 'package:pirate_dot/render/hd/species/boss_crabs.dart';
import 'package:pirate_dot/render/hd/species/boss_fish.dart';
import 'package:pirate_dot/render/hd/species/boss_glacier2.dart';
import 'package:pirate_dot/render/hd/species/boss_jellies.dart';
import 'package:pirate_dot/render/hd/species/boss_misc.dart';
import 'package:pirate_dot/render/hd/species/boss_rays.dart';
import 'package:pirate_dot/render/hd/species/boss_serpents.dart';
import 'package:pirate_dot/render/hd/species/boss_storm2.dart';
import 'package:pirate_dot/render/hd/species/boss_undead.dart';
import 'package:pirate_dot/render/hd/species/boss_volcano2.dart';
import 'package:pirate_dot/render/hd/species/crab.dart';
import 'package:pirate_dot/render/hd/species/cursegull.dart';
import 'package:pirate_dot/render/hd/species/deep_sub.dart';
import 'package:pirate_dot/render/hd/species/eel.dart';
import 'package:pirate_dot/render/hd/species/enemy_ship.dart';
import 'package:pirate_dot/render/hd/species/fire_pirate.dart';
import 'package:pirate_dot/render/hd/species/firebird.dart';
import 'package:pirate_dot/render/hd/species/flyingfish.dart';
import 'package:pirate_dot/render/hd/species/frost_pirate.dart';
import 'package:pirate_dot/render/hd/species/ghost_admiral.dart';
import 'package:pirate_dot/render/hd/species/ghost_ship.dart';
import 'package:pirate_dot/render/hd/species/ghostjelly.dart';
import 'package:pirate_dot/render/hd/species/gull.dart';
import 'package:pirate_dot/render/hd/species/hunter_sub.dart';
import 'package:pirate_dot/render/hd/species/ice_slime.dart';
import 'package:pirate_dot/render/hd/species/iceberg_walrus.dart';
import 'package:pirate_dot/render/hd/species/icebreaker.dart';
import 'package:pirate_dot/render/hd/species/icecrab.dart';
import 'package:pirate_dot/render/hd/species/jelly.dart';
import 'package:pirate_dot/render/hd/species/kraken.dart';
import 'package:pirate_dot/render/hd/species/kraken_titan.dart';
import 'package:pirate_dot/render/hd/species/lava_slime.dart';
import 'package:pirate_dot/render/hd/species/lavacrab.dart';
import 'package:pirate_dot/render/hd/species/lavacrab_small.dart';
import 'package:pirate_dot/render/hd/species/lavaturtle.dart';
import 'package:pirate_dot/render/hd/species/leviathan.dart';
import 'package:pirate_dot/render/hd/species/monster_whale.dart';
import 'package:pirate_dot/render/hd/species/penguin.dart';
import 'package:pirate_dot/render/hd/species/piranha.dart';
import 'package:pirate_dot/render/hd/species/poseidon.dart';
import 'package:pirate_dot/render/hd/species/puffer.dart';
import 'package:pirate_dot/render/hd/species/raider_ship.dart';
import 'package:pirate_dot/render/hd/species/sea_croc.dart';
import 'package:pirate_dot/render/hd/species/seal.dart';
import 'package:pirate_dot/render/hd/species/siphon.dart';
import 'package:pirate_dot/render/hd/species/skeleton.dart';
import 'package:pirate_dot/render/hd/species/snowgull.dart';
import 'package:pirate_dot/render/hd/species/squid.dart';
import 'package:pirate_dot/render/hd/species/starfish.dart';
import 'package:pirate_dot/render/hd/species/starfish_small.dart';
import 'package:pirate_dot/render/hd/species/storm_pirate.dart';
import 'package:pirate_dot/render/hd/species/storm_raider.dart';
import 'package:pirate_dot/render/hd/species/stormgull.dart';
import 'package:pirate_dot/render/hd/species/urchin.dart';
import 'package:pirate_dot/render/hd/species/wraith.dart';
import 'package:pirate_dot/render/hd/species/wraith_ship.dart';

/// HD 카툰 종 목록 — 키는 엔진 적 kind(regions 적·fx_map bossLook 보스). 여기 없는 종은 지금 도트로 그린다(섞여도 동작).
/// 한 종 추가 = `species/<kind>.dart` 하나 + 여기 한 줄(docs/specs/render-hd-style.md 6절).
const Map<String, HdSpecies> hdEnemies = {
  'crab': crab,
  'jelly': jelly,
  'piranha': piranha,
  // B 묶음(S2 — 화산·심연·유령, docs/specs/economy-hd-monsters-b.md)
  'starfish': starfish,
  'starfish_small': starfishSmall,
  'lavacrab': lavacrab,
  'lavacrab_small': lavacrabSmall,
  'lavaturtle': lavaturtle,
  'firebird': firebird,
  // S5 묶음 A(산호·폭풍·빙하, docs/specs/platform-hd-monsters-a.md)
  'gull': gull,
  'stormgull': stormgull,
  'urchin': urchin,
  'flyingfish': flyingfish,
  'puffer': puffer,
  'icecrab': icecrab,
  'icecrab_small': icecrabSmall,
  'penguin': penguin,
  'seal': seal,
  'snowgull': snowgull,
  'angler': angler,
  'squid': squid,
  'siphon': siphon,
  'eel': eel,
  'skeleton': skeleton,
  'ghostjelly': ghostjelly,
  'cursegull': cursegull,
  'wraith': wraith,
};

/// HD v2 표정 3종(평소·공격 예고·쓰러짐)을 굽는 보스 — 굽기가 시트에 2행을 더한다.
const Set<String> hdMoodSpecies = {'sea_croc', 'ice_slime', 'kraken_titan', 'leviathan', 'monster_whale', 'poseidon'};

const Map<String, HdSpecies> hdBosses = {
  // S5 배 보스 무리(공용 몸 boss_ship.dart — 순환 6 + 중간 6)
  'enemy_ship': enemyShip,
  'storm_raider': stormRaider,
  'frost_pirate': frostPirate,
  'blaze_pirate': blazePirate,
  'hunter_sub': hunterSub,
  'wraith_ship': wraithShip,
  'raider_ship': raiderShip,
  'storm_pirate': stormPirate,
  'icebreaker': icebreaker,
  'fire_pirate': firePirate,
  'deep_sub': deepSub,
  'ghost_ship': ghostShip,
  'coral_golem': coralGolem,
  'clown_king': clownKing,
  'pearl_clam': pearlClam,
  'storm_eagle': stormEagle,
  'cloud_whale': cloudWhale,
  'thunder_crab': thunderCrab,
  'frost_yeti': frostYeti,
  'ice_narwhal': iceNarwhal,
  'snow_owl_ship': snowOwlShip,
  'magma_golem': magmaGolem,
  'fire_salamander': fireSalamander,
  'ash_dragon': ashDragon,
  'ghost_admiral': ghostAdmiral,
  'kraken': kraken,
  // 대보스 6(S3)
  'ice_slime': iceSlime,
  'sea_croc': seaCroc,
  'kraken_titan': krakenTitan,
  'leviathan': leviathan,
  'monster_whale': monsterWhale,
  'poseidon': poseidon,
  // 해역·중간 보스(S3)
  'jelly_queen': jellyQueen,
  'phantom_jelly': phantomJelly,
  'flame_eel': flameEel,
  'great_serpent': greatSerpent,
  'icecrab_chief': icecrabChief,
  'hermit_conch': hermitConch,
  'lava_slime': lavaSlime,
  'angler_king': anglerKing,
  'hammer_shark': hammerShark,
  'twister_dolphin': twisterDolphin,
  'thunder_ray_pup': thunderRayPup,
  'deep_octopus': deepOctopus,
  'giant_squid': giantSquid,
  'cursegull_leader': cursegullLeader,
  'lava_tortoise': lavaTortoise,
  'seal_chief': sealChief,
  'skeleton_captain': skeletonCaptain,
  'specter': specter,
  // 해역 보스(S3)
  'giant_hermit': giantHermit,
  'thunder_ray': thunderRay,
  'lava_whale': lavaWhale,
  'iceberg_walrus': icebergWalrus,
  'kraken_tentacle': krakenTentacle,
};
