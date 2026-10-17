import 'dart:ui';

import 'package:game_data/game_data.dart';
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
/// 비동기 없음, 골든도 같은 그림). 해상도가 15% 넘게 바뀌면(회전·창 크기) 다시 굽는다.
/// 캐시 상한은 장 수가 아니라 텍스처 바이트([budgetBytes]) — 보스 시트는 잡몹의 10~30배라(밀도 6에서 보스 7MB·잡몹 0.56MB,
/// S5 측정 test/render/hd_bake_perf_test) 장 수로 막으면 큰 보스가 쌓여 수십 MB가 된다. 넘으면 오래 안 쓴 것부터 버린다.
class HdSheets {
  final Map<String, HdSheet> _ready = {};
  final Map<String, int> _used = {};
  double _density = 0;
  int _tick = 0;

  /// 텍스처 캐시 상한(바이트) — 한 해역(잡몹 5 + 보스 몇)을 넉넉히 담고 저사양 폰에서도 부담 없는 크기.
  static const int budgetBytes = 48 * 1024 * 1024;
  int _bytes = 0;

  /// 지금 캐시에 든 텍스처 바이트(측정·시험용).
  int get bytes => _bytes;

  /// HD 잡몹은 도트 칸보다 1.3배 크게 그린다(맞는 자리는 그대로 — 귀엽고 잘 보이게, S1 '귀엽지만 멋지고 화려').
  static const enemyBoost = 1.3;

  /// 그리는 크기(단위): 잡몹은 [enemyBoost]배.
  static double drawWorld(double world, {required bool boss}) => boss ? world : world * enemyBoost;

  /// 칸 한 변 최대 px(대보스 메모리 상한 — 512² × 16장 ≈ 16MB). 저사양(절전·발열)은 [lowCell].
  static const maxCell = 512.0;
  static const lowCell = 384.0;

  /// 지금 칸 상한 — 바뀌면 다시 굽는다(TopEnemies가 절전 여부로 매 프레임 넣는다).
  double get cap => _cap;
  set cap(double v) {
    if (v == _cap) return;
    _cap = v;
    clear(_density);
  }

  double _cap = maxCell;

  // ---- 미리 굽기(S5 측정: 폰에서 보스 첫 등장 프레임 40~120ms 끊김 → 스테이지가 바뀌면 그 해역 잡몹 + 이번 보스를
  // 프레임당 한 종씩 미리 굽는다) ----
  final List<(String, bool, double)> _queue = [];
  int _planned = -1;

  /// 스테이지 [stage]가 바뀌면 줄을 세운다. [worldOf] = 그 종의 칸 크기(단위, 도트 그림 없으면 null).
  void plan(int stage, RegionsTable regions, double? Function(String kind, {required bool boss}) worldOf) {
    if (stage == _planned || stage <= 0) return;
    _planned = stage;
    _queue.clear();
    void add(String kind, {required bool boss}) {
      if ((boss ? hdBosses : hdEnemies)[kind] == null || _ready.containsKey(boss ? 'b:$kind' : kind)) return;
      final w0 = worldOf(kind, boss: boss);
      final w = w0 == null ? null : drawWorld(w0, boss: boss);
      if (w != null) _queue.add((kind, boss, w));
    }

    add(regions.bossAt(stage).id, boss: true);
    for (final e in regions.regionAt(stage).enemies) {
      add(e, boss: false);
    }
  }

  /// 프레임당 한 종(줄이 비면 아무것도 안 함). 밀도를 아직 모르면 기다린다.
  void step(double density) {
    if (_queue.isEmpty || density <= 0) return;
    final (kind, boss, world) = _queue.removeAt(0);
    sheet(kind, boss: boss, world: world, density: density);
  }

  /// 남은 미리 굽기 수(시험).
  int get queued => _queue.length;

  /// [kind](보스면 [boss]) 시트. HD 종이 아니면 null(도트로 그린다). [world] = 전장 크기(단위), [density] = 단위당 기기 px.
  HdSheet? sheet(String kind, {required bool boss, required double world, required double density}) {
    final sp = (boss ? hdBosses : hdEnemies)[kind];
    if (sp == null) return null;
    if (_density == 0 || (density / _density - 1).abs() > 0.15) clear(density);
    final key = boss ? 'b:$kind' : kind;
    _used[key] = ++_tick;
    final have = _ready[key];
    if (have != null) return have;
    final sheet = bake(sp, world, _density, cap: _cap);
    _bytes += _sizeOf(sheet);
    _ready[key] = sheet;
    // 바이트 상한을 넘으면 오래 안 쓴 것부터(방금 구운 것은 남긴다).
    while (_bytes > budgetBytes && _ready.length > 1) {
      _evict(except: key);
    }
    return sheet;
  }

  static int _sizeOf(HdSheet s) => s.image.width * s.image.height * 4;

  void clear([double density = 0]) {
    for (final s in _ready.values) {
      s.image.dispose();
    }
    _ready.clear();
    _used.clear();
    _bytes = 0;
    _density = density;
  }

  void _evict({required String except}) {
    final old = _ready.keys.where((k) => k != except).reduce((a, b) => (_used[a] ?? 0) <= (_used[b] ?? 0) ? a : b);
    final gone = _ready.remove(old);
    if (gone != null) {
      _bytes -= _sizeOf(gone);
      gone.image.dispose();
    }
    _used.remove(old);
  }

  /// 한 종을 8장 × 2방향으로 굽는다(각 칸은 잘라 옆 칸에 번지지 않게).
  static HdSheet bake(HdSpecies sp, double world, double density, {double cap = maxCell}) {
    final cell = (world * density).clamp(16.0, cap).roundToDouble();
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
