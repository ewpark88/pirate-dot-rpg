import 'package:game_data/src/models/common.dart';

/// 타격감 수치(juice.json). 렌더 레인이 읽고, 운영자 모드에서 슬라이더로 조절한다.
class JuiceTable {
  JuiceTable.fromJson(this.raw)
    : maxEffects = raw.obj('limits').integer('effects'),
      maxDamageNumbers = raw.obj('limits').integer('damageNumbers'),
      hitStopMs = raw.numberMap('hitStopMs');

  final JsonReader raw;
  final int maxEffects;
  final int maxDamageNumbers;
  final Map<String, double> hitStopMs;

  List<String> validate() {
    final e = <String>[];
    expect(e, that: maxEffects > 0 && maxEffects <= 64, message: 'juice: limits.effects는 1~64');
    expect(e, that: maxDamageNumbers > 0, message: 'juice: limits.damageNumbers > 0');
    return e;
  }
}

class FxSheetDef {
  FxSheetDef.fromJson(JsonReader j)
    : id = j.str('id'),
      w = j.integer('w'),
      h = j.integer('h'),
      frames = j.integer('frames');

  final String id;
  final int w;
  final int h;
  final int frames;
}

/// 게임 이벤트 → 이펙트·효과음 (fx_map.json).
class FxMapTable {
  FxMapTable.fromJson(JsonReader j)
    : events = {
        for (final k in j.obj('events').raw.keys) k: j.obj('events').obj(k),
      },
      sheets = j.objs('fxSheets').map(FxSheetDef.fromJson).toList();

  final Map<String, JsonReader> events;
  final List<FxSheetDef> sheets;

  List<String> validate() {
    final e = <String>[];
    final ids = sheets.map((s) => s.id).toSet();
    for (final ev in events.entries) {
      final fx = ev.value.strOrNull('fx');
      expect(e, that: fx == null || ids.contains(fx), message: 'fx_map: ${ev.key}의 fx $fx가 fxSheets에 없음');
    }
    return e;
  }
}
