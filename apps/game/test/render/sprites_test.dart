import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

void main() {
  test('경로 표: 초상 40명·적 시트 2프레임·이펙트 프레임·배·코인', () {
    final paths = SpriteBank.manifest(tables);
    expect(paths.where((p) => p.key.startsWith('crew:')).length, tables.crews.crews.length);
    expect(paths.firstWhere((p) => p.key == 'crew:octo').path, 'crews/octo.png');
    final crab = paths.firstWhere((p) => p.key == 'enemy:crab');
    expect((crab.path, crab.frames), ('enemies/crab.png', tables.fxMap.sprites.integer('enemyFrames')));
    final fx = paths.firstWhere((p) => p.key == 'fx:explosion_aoe');
    expect((fx.path, fx.frames), ('fx/explosion_aoe.png', tables.fxMap.sheet('explosion_aoe')!.frames));
    expect(paths.firstWhere((p) => p.key == 'projectile:lob').path, 'projectiles/cannonball.png');
    expect(paths.firstWhere((p) => p.key == 'ship:dinghy').path, 'ship/ship_t1.png');
    expect(paths.firstWhere((p) => p.key == 'boss:enemy_ship').path, 'bosses/enemy_ship.png');
    expect(paths.firstWhere((p) => p.key == 'coin').frames, tables.fxMap.sprites.integer('coinFrames'));
  });

  // 스펙 render-art-enemies: 해역 묶음마다 하나씩 늘린다 (플레이스홀더 0).
  for (final regionId in ['coral', 'storm', 'glacier', 'volcano', 'abyss', 'phantom']) {
    test('render-art-enemies: $regionId 해역의 적·보스가 모두 스프라이트 파일이 있다', () {
      final r = tables.regions.regions.firstWhere((r) => r.id == regionId);
      final paths = {for (final p in SpriteBank.manifest(tables)) p.key: p.path};
      final keys = [
        for (final e in r.enemies) 'enemy:$e',
        for (final b in {r.boss, r.midBoss, r.regionBoss}) 'boss:$b',
      ];
      for (final k in keys) {
        expect(paths[k], isNotNull, reason: '$k 경로 없음');
        expect(File('assets/${paths[k]}').existsSync(), isTrue, reason: '$k → assets/${paths[k]}');
      }
    });
  }

  test('배 등급 그림이 모두 있다 (t1~t4)', () {
    final paths = {for (final p in SpriteBank.manifest(tables)) p.key: p.path};
    for (final tier in tables.shipTiers.tiers) {
      expect(File('assets/${paths['ship:${tier.id}']}').existsSync(), isTrue, reason: tier.id);
    }
  });

  test('빈 뱅크는 아무것도 없다', () {
    expect(SpriteBank().isEmpty, isTrue);
    expect(SpriteBank()['enemy:crab'], isNull);
  });
}
