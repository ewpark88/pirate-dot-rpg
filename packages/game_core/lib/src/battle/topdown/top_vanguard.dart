import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/battle/topdown/top_spawn.dart';
import 'package:game_core/src/engine/game_engine.dart';

/// 돌격대 (사용자 결정 2026-10-16, S1·S2 — 파밍 파 배 피해 1% 미만 → 5~15%): 무리 한 파마다 waves.top.vanguard
/// {count, hpMul, speedMul, fromStage}마리를 더한다. 그 파 무리 한 마리를 본떠 HP × hpMul·속도 × speedMul, 넉백·기절·끌기 면역,
/// 겹침 풀기 없이 배로 곧장 와서 박는다(접촉 피해는 한 대 상한). 표에 없으면 없음.
void addVanguard(Field f, int stage, SystemContext ctx, List<Foe> wave) {
  final top = ctx.tables.waves.raw.obj('top');
  final g = f.geometry;
  if (!top.has('vanguard') || g is! TopGeometry) return;
  final v = top.obj('vanguard');
  if (stage < (v.intOrNull('fromStage') ?? 1)) return;
  final model = wave.where((e) => !e.boss && e.ownerId == null && e.eventKind == null).firstOrNull;
  if (model == null) return;
  final spawn = TopSpawn(g.top, ctx.tables.waves.field.spawnSpacing);
  for (var i = 0; i < v.integer('count'); i++) {
    final e = Foe(
      id: f.nextId(),
      kind: model.kind,
      layer: model.layer,
      x: 0,
      y: 0,
      maxHp: model.maxHp.times(v.number('hpMul')),
      speed: model.speed * v.number('speedMul'),
      attack: model.attack,
      gold: model.gold.times(v.number('hpMul')),
      def: model.def,
    )..vanguard = true;
    final angle = spawn.heading(ctx.rng);
    spawn.place(e, angle, spawn.startDistance(e, angle));
    f.foes.add(e);
  }
}
