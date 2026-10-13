import 'dart:convert';

import 'package:game_data/src/models/battle_tables.dart';
import 'package:game_data/src/models/common.dart';
import 'package:game_data/src/models/crew_tables.dart';
import 'package:game_data/src/models/economy_tables.dart';
import 'package:game_data/src/models/render_tables.dart';
import 'package:game_data/src/tables.g.dart';

/// 모든 데이터 테이블. [GameTables.load]로 만들면 검증까지 끝난 상태다.
class GameTables {
  GameTables._({
    required this.crews,
    required this.rarities,
    required this.growth,
    required this.shipParts,
    required this.shipTiers,
    required this.skills,
    required this.waves,
    required this.regions,
    required this.juice,
    required this.fxMap,
    required this.ads,
    required this.meta,
  });

  /// [raw]를 주지 않으면 앱에 심은 테이블(tables.g.dart)을 쓴다.
  /// 형식이 틀리면 [TableFormatException], 값이 틀리면 [TableValidationException].
  factory GameTables.load([Map<String, String>? raw]) {
    final src = raw ?? rawTables;
    JsonReader read(String name) {
      final text = src[name];
      if (text == null) throw TableFormatException(name, '테이블이 없습니다');
      return JsonReader(jsonDecode(text) as Map<String, dynamic>, name);
    }

    final t = GameTables._(
      crews: CrewTable.fromJson(read('crews')),
      rarities: RarityTable.fromJson(read('rarities')),
      growth: GrowthTable.fromJson(read('growth')),
      shipParts: ShipPartsTable.fromJson(read('ship_parts')),
      shipTiers: ShipTiersTable.fromJson(read('ship_tiers')),
      skills: SkillsTable.fromJson(read('skills')),
      waves: WavesTable.fromJson(read('waves')),
      regions: RegionsTable.fromJson(read('regions')),
      juice: JuiceTable.fromJson(read('juice')),
      fxMap: FxMapTable.fromJson(read('fx_map')),
      ads: AdsTable.fromJson(read('ads')),
      meta: MetaTable.fromJson(read('meta')),
    );
    final errors = t.validate();
    if (errors.isNotEmpty) throw TableValidationException(errors);
    return t;
  }

  final CrewTable crews;
  final RarityTable rarities;
  final GrowthTable growth;
  final ShipPartsTable shipParts;
  final ShipTiersTable shipTiers;
  final SkillsTable skills;
  final WavesTable waves;
  final RegionsTable regions;
  final JuiceTable juice;
  final FxMapTable fxMap;
  final AdsTable ads;
  final MetaTable meta;

  /// 테이블 하나씩의 검증 + 테이블 사이 참조 검증.
  List<String> validate() {
    final e = <String>[
      ...crews.validate(),
      ...rarities.validate(),
      ...growth.validate(rarities),
      ...shipParts.validate(),
      ...shipTiers.validate(),
      ...skills.validate(shipParts.skillCooldownMinSec),
      ...waves.validate(),
      ...regions.validate(),
      ...juice.validate(),
      ...fxMap.validate(),
      ...ads.validate(),
      ...meta.validate(),
    ];
    final fxIds = fxMap.sheets.map((s) => s.id).toSet();
    final familyIds = skills.families.map((f) => f.id).toSet();
    expect(e, that: familyIds.containsAll(crewFamilies), message: 'skills: 계열 8종이 모두 있어야 함');
    for (final c in crews.crews) {
      expect(e, that: familyIds.contains(c.family), message: 'crews: ${c.id}의 계열 ${c.family}가 skills에 없음');
      expect(e, that: fxIds.contains(c.fx), message: 'crews: ${c.id}의 fx ${c.fx}가 fx_map에 없음');
      expect(e, that: rarityOrder.contains(c.baseRarity), message: 'crews: ${c.id}의 등급 오류');
    }
    for (final f in skills.families) {
      expect(e, that: fxIds.contains(f.skill.fx), message: 'skills: ${f.id} 스킬 fx ${f.skill.fx}가 fx_map에 없음');
    }
    return e;
  }
}
