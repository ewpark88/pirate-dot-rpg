import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/boss_cephalo.dart';
import 'package:pirate_dot/render/hd/species/boss_crabs.dart';
import 'package:pirate_dot/render/hd/species/boss_fish.dart';
import 'package:pirate_dot/render/hd/species/boss_jellies.dart';
import 'package:pirate_dot/render/hd/species/boss_misc.dart';
import 'package:pirate_dot/render/hd/species/boss_serpents.dart';
import 'package:pirate_dot/render/hd/species/boss_undead.dart';
import 'package:pirate_dot/render/hd/species/crab.dart';
import 'package:pirate_dot/render/hd/species/ice_slime.dart';
import 'package:pirate_dot/render/hd/species/jelly.dart';
import 'package:pirate_dot/render/hd/species/kraken.dart';
import 'package:pirate_dot/render/hd/species/kraken_titan.dart';
import 'package:pirate_dot/render/hd/species/lava_slime.dart';
import 'package:pirate_dot/render/hd/species/leviathan.dart';
import 'package:pirate_dot/render/hd/species/monster_whale.dart';
import 'package:pirate_dot/render/hd/species/piranha.dart';
import 'package:pirate_dot/render/hd/species/poseidon.dart';
import 'package:pirate_dot/render/hd/species/sea_croc.dart';

/// HD 카툰 종 목록 — 키는 엔진 적 kind(regions 적·fx_map bossLook 보스). 여기 없는 종은 지금 도트로 그린다(섞여도 동작).
/// 한 종 추가 = `species/<kind>.dart` 하나 + 여기 한 줄(docs/specs/render-hd-style.md 6절).
const Map<String, HdSpecies> hdEnemies = {
  'crab': crab,
  'jelly': jelly,
  'piranha': piranha,
};

const Map<String, HdSpecies> hdBosses = {
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
};
