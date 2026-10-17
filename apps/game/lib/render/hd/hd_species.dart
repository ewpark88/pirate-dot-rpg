import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/angler.dart';
import 'package:pirate_dot/render/hd/species/crab.dart';
import 'package:pirate_dot/render/hd/species/cursegull.dart';
import 'package:pirate_dot/render/hd/species/eel.dart';
import 'package:pirate_dot/render/hd/species/firebird.dart';
import 'package:pirate_dot/render/hd/species/flyingfish.dart';
import 'package:pirate_dot/render/hd/species/ghostjelly.dart';
import 'package:pirate_dot/render/hd/species/gull.dart';
import 'package:pirate_dot/render/hd/species/icecrab.dart';
import 'package:pirate_dot/render/hd/species/jelly.dart';
import 'package:pirate_dot/render/hd/species/kraken.dart';
import 'package:pirate_dot/render/hd/species/lavacrab.dart';
import 'package:pirate_dot/render/hd/species/lavacrab_small.dart';
import 'package:pirate_dot/render/hd/species/lavaturtle.dart';
import 'package:pirate_dot/render/hd/species/penguin.dart';
import 'package:pirate_dot/render/hd/species/piranha.dart';
import 'package:pirate_dot/render/hd/species/puffer.dart';
import 'package:pirate_dot/render/hd/species/seal.dart';
import 'package:pirate_dot/render/hd/species/siphon.dart';
import 'package:pirate_dot/render/hd/species/skeleton.dart';
import 'package:pirate_dot/render/hd/species/snowgull.dart';
import 'package:pirate_dot/render/hd/species/squid.dart';
import 'package:pirate_dot/render/hd/species/starfish.dart';
import 'package:pirate_dot/render/hd/species/starfish_small.dart';
import 'package:pirate_dot/render/hd/species/stormgull.dart';
import 'package:pirate_dot/render/hd/species/urchin.dart';
import 'package:pirate_dot/render/hd/species/wraith.dart';

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

const Map<String, HdSpecies> hdBosses = {
  'kraken': kraken,
};
