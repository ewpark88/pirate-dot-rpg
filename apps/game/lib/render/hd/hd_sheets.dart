import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// 굽힌 HD 시트: 칸 [cell]px 정사각 × 8열(고리 0.1초씩) × 2행(0 = 왼쪽 봄 그대로, 1 = 좌우 뒤집어 오른쪽 봄).
/// 전장 크기 [world]단위(지금 도트 칸과 같은 자리 크기)로 그린다 — 배율 = world / cell.
class HdSheet {
  HdSheet(this.image, this.cell, this.world);

  final Image image;
  final double cell;
  final double world;

  double get scale => world / cell;

  Rect src(int frame, {required bool right}) => Rect.fromLTWH(frame * cell, right ? cell : 0, cell, cell);
}

/// HD 카툰 굽기(docs/specs/render-hd-style.md 5절): 코드 벡터 종을 처음 보일 때 기기 해상도로 한 장에 굽는다(toImageSync —
/// 비동기 없음, 골든도 같은 그림). 해상도가 15% 넘게 바뀌면(회전·창 크기) 다시 굽는다. 오래 안 쓴 시트는 [_keep]장 넘으면 버린다.
class HdSheets {
  final Map<String, HdSheet> _ready = {};
  final Map<String, int> _used = {};
  double _density = 0;
  int _tick = 0;
  static const _keep = 14;

  /// 칸 한 변 최대 px(대보스 메모리 상한 — 512² × 16장 ≈ 16MB).
  static const maxCell = 512.0;

  /// [kind](보스면 [boss]) 시트. HD 종이 아니면 null(도트로 그린다). [world] = 전장 크기(단위), [density] = 단위당 기기 px.
  HdSheet? sheet(String kind, {required bool boss, required double world, required double density}) {
    final sp = (boss ? hdBosses : hdEnemies)[kind];
    if (sp == null) return null;
    if (_density == 0 || (density / _density - 1).abs() > 0.15) clear(density);
    final key = boss ? 'b:$kind' : kind;
    _used[key] = ++_tick;
    final have = _ready[key];
    if (have != null) return have;
    if (_ready.length >= _keep) _evict();
    return _ready[key] = bake(sp, world, _density);
  }

  void clear([double density = 0]) {
    for (final s in _ready.values) {
      s.image.dispose();
    }
    _ready.clear();
    _used.clear();
    _density = density;
  }

  void _evict() {
    final old = _ready.keys.reduce((a, b) => (_used[a] ?? 0) <= (_used[b] ?? 0) ? a : b);
    _ready.remove(old)?.image.dispose();
    _used.remove(old);
  }

  /// 한 종을 8장 × 2방향으로 굽는다(각 칸은 잘라 옆 칸에 번지지 않게).
  static HdSheet bake(HdSpecies sp, double world, double density) {
    final cell = (world * density).clamp(16.0, maxCell).roundToDouble();
    final r = cell / (2 * sp.extent);
    final rec = PictureRecorder();
    final c = Canvas(rec);
    final k = HdKit();
    for (var f = 0; f < HdKit.frames; f++) {
      for (var row = 0; row < 2; row++) {
        c
          ..save()
          ..clipRect(Rect.fromLTWH(f * cell, row * cell, cell, cell))
          ..translate(f * cell + cell / 2, row * cell + cell / 2);
        if (row == 1) c.scale(-1, 1);
        k
          ..begin(r)
          ..shadow(c, r, sp.ground);
        sp.draw(k, c, r, f * HdKit.loopMs / HdKit.frames);
        c.restore();
      }
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync((cell * HdKit.frames).toInt(), (cell * 2).toInt());
    pic.dispose();
    return HdSheet(img, cell, world);
  }
}
