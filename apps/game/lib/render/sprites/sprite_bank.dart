import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:game_data/game_data.dart';

/// 스프라이트 시트 한 장: 가로로 [frames]장.
class SpriteSheet {
  SpriteSheet(this.image, this.frames);

  final ui.Image image;
  final int frames;

  double get frameW => image.width / frames;
  double get frameH => image.height.toDouble();
}

/// 키 → 에셋 경로·프레임 수 (`assets/` 아래).
typedef SpriteEntry = ({String key, String path, int frames});

/// 아트 팩 이미지 (docs/specs/render-art-pack-v02.md 규칙 5). 없는 키는 null → 그리는 쪽이 플레이스홀더를 쓴다.
///
/// 키: `crew:<id>` · `enemy:<kind>` · `boss:<kind>` · `ship` · `projectile:<family>` · `fx:<sheetId>` · `coin`.
class SpriteBank {
  final Map<String, SpriteSheet> _sheets = {};

  bool get isEmpty => _sheets.isEmpty;
  int get length => _sheets.length;

  SpriteSheet? operator [](String key) => _sheets[key];

  void put(String key, ui.Image image, {int frames = 1}) => _sheets[key] = SpriteSheet(image, frames);

  /// 읽어 볼 에셋 목록. 경로는 테이블(crews.json portrait, skills.json projectile, fx_map fxSheets)에서 나온다.
  static List<SpriteEntry> manifest(GameTables t) {
    final fx = t.fxMap;
    final enemyFrames = fx.sprites.integer('enemyFrames');
    return [
      for (final c in t.crews.crews) (key: 'crew:${c.id}', path: c.portrait, frames: 1),
      for (final k in t.regions.enemies.keys) (key: 'enemy:$k', path: 'enemies/$k.png', frames: enemyFrames),
      for (final b in fx.bossLook.keys) (key: 'boss:$b', path: 'bosses/$b.png', frames: 1),
      (key: 'ship', path: 'ship/ship_t1.png', frames: 1),
      for (final f in t.skills.families)
        if (f.projectile != null) (key: 'projectile:${f.id}', path: 'projectiles/${f.projectile}.png', frames: 1),
      for (final s in fx.sheets) (key: 'fx:${s.id}', path: 'fx/${s.id}.png', frames: s.frames),
      (key: 'coin', path: 'coin.png', frames: fx.sprites.integer('coinFrames')),
    ];
  }

  /// 목록의 에셋을 읽는다. 없거나 읽지 못한 것은 건너뛴다(플레이스홀더).
  static Future<SpriteBank> load(Images images, GameTables tables) async {
    final bank = SpriteBank();
    for (final e in manifest(tables)) {
      try {
        bank.put(e.key, await images.load(e.path), frames: e.frames);
      } on Object {
        // 에셋이 아직 없다(아트 레인 미적용) — 플레이스홀더로 그린다.
      }
    }
    return bank;
  }
}
