import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/species/crab.dart';
import 'package:pirate_dot/render/hd/species/flyingfish.dart';
import 'package:pirate_dot/render/hd/species/gull.dart';
import 'package:pirate_dot/render/hd/species/jelly.dart';
import 'package:pirate_dot/render/hd/species/kraken.dart';
import 'package:pirate_dot/render/hd/species/piranha.dart';
import 'package:pirate_dot/render/hd/species/puffer.dart';
import 'package:pirate_dot/render/hd/species/stormgull.dart';
import 'package:pirate_dot/render/hd/species/urchin.dart';

/// HD 카툰 종 목록 — 키는 엔진 적 kind(regions 적·fx_map bossLook 보스). 여기 없는 종은 지금 도트로 그린다(섞여도 동작).
/// 한 종 추가 = `species/<kind>.dart` 하나 + 여기 한 줄(docs/specs/render-hd-style.md 6절).
const Map<String, HdSpecies> hdEnemies = {
  'crab': crab,
  'jelly': jelly,
  'piranha': piranha,
  // S5 묶음 A(산호·폭풍·빙하, docs/specs/platform-hd-monsters-a.md)
  'gull': gull,
  'stormgull': stormgull,
  'urchin': urchin,
  'flyingfish': flyingfish,
  'puffer': puffer,
};

const Map<String, HdSpecies> hdBosses = {
  'kraken': kraken,
};
