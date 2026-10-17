import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

void main() {
  test('경로 표: 초상 40명·적 시트 2프레임·이펙트 프레임·배·코인', () {
    final paths = SpriteBank.manifest(tables);
    expect(paths.where((p) => p.key.startsWith('crew:')).length, tables.crews.crews.length);
    expect(paths.firstWhere((p) => p.key == 'crew:octo').path, 'crews/octo.png');
    final crab = paths.firstWhere((p) => p.key == 'td_enemy:crab');
    expect((crab.path, crab.frames), ('enemies/td_crab.png', 2));
    expect(
      paths.where((p) => p.key.startsWith('enemy:') || p.key.startsWith('ship:') || p.key.startsWith('ship_')),
      isEmpty,
      reason: '옆모습 그림은 T4-3에서 지웠다',
    );
    final fx = paths.firstWhere((p) => p.key == 'fx:explosion_aoe');
    expect((fx.path, fx.frames), ('fx/explosion_aoe.png', tables.fxMap.sheet('explosion_aoe')!.frames));
    expect(paths.firstWhere((p) => p.key == 'projectile:lob').path, 'projectiles/cannonball.png');
    expect(paths.firstWhere((p) => p.key == 'td:dinghy:hull').path, 'ship/td_t1_hull.png');
    expect(paths.firstWhere((p) => p.key == 'boss:enemy_ship').path, 'bosses/enemy_ship.png');
    expect(paths.firstWhere((p) => p.key == 'coin').frames, tables.fxMap.sprites.integer('coinFrames'));
  });

  // 스펙 render-art-enemies: 해역 묶음마다 하나씩 늘린다 (플레이스홀더 0).
  for (final regionId in ['coral', 'storm', 'glacier', 'volcano', 'abyss', 'phantom']) {
    test('render-art-enemies: $regionId 해역의 적·보스가 모두 스프라이트 파일이 있다', () {
      final r = tables.regions.regions.firstWhere((r) => r.id == regionId);
      final paths = {for (final p in SpriteBank.manifest(tables)) p.key: p.path};
      final keys = [
        for (final e in r.enemies) 'td_enemy:$e',
        // 도감 v2: 보통 보스 순환·10단위 대보스도(표에 들어오면 그림이 있어야 한다).
        for (final b in {r.boss, r.midBoss, r.regionBoss, ...r.bossRotation, ?r.wallBoss}) ...['boss:$b', 'td_boss:$b'],
      ];
      for (final k in keys) {
        expect(paths[k], isNotNull, reason: '$k 경로 없음');
        expect(File('assets/${paths[k]}').existsSync(), isTrue, reason: '$k → assets/${paths[k]}');
      }
    });
  }

  test('도감 v2 대보스 6종: 탑다운 2프레임 88도트 + 컷인 초상', () {
    final paths = {for (final p in SpriteBank.manifest(tables)) p.key: p.path};
    for (final b in ['sea_croc', 'monster_whale', 'ice_slime', 'leviathan', 'kraken_titan', 'poseidon']) {
      for (final k in ['td_boss:$b', 'boss:$b']) {
        expect(paths[k], isNotNull, reason: '$k — fx_map bossLook에 없음');
        expect(File('assets/${paths[k]}').existsSync(), isTrue, reason: '$k → assets/${paths[k]}');
      }
    }
  });

  test('도감 v2 보통 보스 23종: 탑다운 2프레임 + 컷인 초상', () {
    final paths = {for (final p in SpriteBank.manifest(tables)) p.key: p.path};
    for (final b in const [
      'hermit_conch', 'jelly_queen', 'hammer_shark', 'storm_raider', 'thunder_ray_pup', 'great_serpent', //
      'twister_dolphin', 'frost_pirate', 'seal_chief', 'giant_squid', 'icecrab_chief', 'blaze_pirate', //
      'lava_tortoise', 'flame_eel', 'lava_slime', 'hunter_sub', 'angler_king', 'deep_octopus', //
      'phantom_jelly', 'wraith_ship', 'skeleton_captain', 'cursegull_leader', 'specter',
    ]) {
      for (final k in ['td_boss:$b', 'boss:$b']) {
        expect(paths[k], isNotNull, reason: '$k — fx_map bossLook에 없음');
        expect(File('assets/${paths[k]}').existsSync(), isTrue, reason: '$k → assets/${paths[k]}');
      }
    }
  });

  test('배 등급 탑다운 층 그림이 모두 있다 (t1~t4)', () {
    final paths = {for (final p in SpriteBank.manifest(tables)) p.key: p.path};
    for (final tier in tables.shipTiers.tiers) {
      expect(File('assets/${paths['td:${tier.id}:hull']}').existsSync(), isTrue, reason: tier.id);
    }
  });

  test('매니페스트에 없는 그림 파일이 없다 (적·배 — APK 크기, T4-3)', () {
    final used = {for (final p in SpriteBank.manifest(tables)) p.path};
    for (final dir in ['enemies', 'ship']) {
      for (final f in Directory('assets/$dir').listSync().whereType<File>()) {
        final rel = '$dir/${f.uri.pathSegments.last}';
        expect(used.contains(rel), isTrue, reason: '$rel 를 아무도 안 쓴다');
      }
    }
  });

  test('빈 뱅크는 아무것도 없다', () {
    expect(SpriteBank().isEmpty, isTrue);
    expect(SpriteBank()['td_enemy:crab'], isNull);
  });
}
