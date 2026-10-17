import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';
import 'package:pirate_dot/render/hd/hd_species.dart';

/// 굽힌 HD 시트: 칸 [cell]px 정사각 × 8열(고리 0.1초씩) × 2행(0 = 왼쪽 봄 그대로, 1 = 좌우 뒤집어 오른쪽 봄).
/// 전장 크기 [world]단위(지금 도트 칸과 같은 자리 크기)로 그린다 — 배율 = world / cell.
/// HD v2 표정 보스([hdMoodSpecies])는 2행을 더 굽는다: 2·3행(왼·오른) = 0~3열 공격 예고 4장 + 4~7열 쓰러짐 4장(0.2초씩).
/// 잡몹 v2([hits])는 2·3행 = 맞을 때 찡긋(> < 눈 + 몸 찌그러짐) 8장.
class HdSheet {
  HdSheet(this.image, this.cell, this.world, {this.moods = false, this.hits = false});

  final Image image;
  final double cell;
  final double world;
  final bool moods;
  final bool hits;

  double get scale => world / cell;

  Rect src(int frame, {required bool right, HdMood mood = HdMood.idle}) {
    if (hits && mood == HdMood.hit) return Rect.fromLTWH(frame * cell, (right ? 3 : 2) * cell, cell, cell);
    if (!moods || mood == HdMood.idle) return Rect.fromLTWH(frame * cell, right ? cell : 0, cell, cell);
    final col = (mood == HdMood.down ? 4 : 0) + (frame >> 1);
    return Rect.fromLTWH(col * cell, (right ? 3 : 2) * cell, cell, cell);
  }
}

/// HD 카툰 굽기(docs/specs/render-hd-style.md 5절): 코드 벡터 종을 처음 보일 때 기기 해상도로 한 장에 굽는다(toImageSync —
/// 비동기 없음, 골든도 같은 그림). 해상도가 15% 넘게 바뀌면(회전·창 크기) 다시 굽는다.
/// 캐시 상한은 장 수가 아니라 텍스처 바이트([budget]) — 보스 시트는 잡몹의 10~30배라(밀도 6에서 보스 7MB·잡몹 0.56MB,
/// S5 측정 test/render/hd_bake_perf_test) 장 수로 막으면 큰 보스가 쌓여 수십 MB가 된다. 넘으면 오래 안 쓴 것부터 버린다.
class HdSheets {
  final Map<String, HdSheet> _ready = {};
  final Map<String, int> _used = {};
  double _density = 0;
  int _tick = 0;

  /// 폰(밀도 [phoneDensity]) 텍스처 캐시 상한(바이트) — 한 해역(잡몹 5 + 보스 몇)을 넉넉히 담고 저사양 폰에서도 부담 없는 크기.
  static const int budgetBytes = 48 * 1024 * 1024;

  /// 태블릿 상한 — 텍스처는 밀도²로 커져 밀도 6(태블릿)에서 한 해역이 약 84MB라 48MB면 해역 안에서도 버렸다 다시 굽는다(S1).
  static const int maxBudgetBytes = 96 * 1024 * 1024;
  static const double phoneDensity = 4;

  /// 지금 밀도의 상한: 폰 48MB × (밀도/4)², 48~96MB(화면이 클수록 같은 종도 텍스처가 커지니 같은 장 수를 담게).
  int get budget {
    final scale = _density / phoneDensity;
    return (budgetBytes * scale * scale).clamp(budgetBytes, maxBudgetBytes).toInt();
  }

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
    // 이번 보스 말고 지난 보스 시트는 버린다(보스 시트는 잡몹의 10~30배 — 해역 내내 쌓이면 수십 MB, S5 PSS 638MB).
    final next = 'b:${regions.bossAt(stage).id}';
    _ready.keys.where((k) => k.startsWith('b:') && k != next).toList().forEach(_drop);
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
    _frame++;
    _reap();
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
    // 다시 굽기: 더 촘촘해야 할 때(+15%) 또는 많이 성길 때(-45%)만 — 보스 카메라 줌이 오가도 매번 다 굽지 않게.
    if (_density == 0 || density > _density * 1.15 || density < _density * 0.55) clear(density);
    final key = boss ? 'b:$kind' : kind;
    _used[key] = ++_tick;
    final have = _ready[key];
    if (have != null) return have;
    final sheet = bake(
      sp,
      world,
      _density,
      cap: _cap,
      moods: boss,
      hits: !boss && _cap >= maxCell, // 찡긋 행은 저사양(lite)이면 안 굽는다(잡몹 시트 절반)
      selfMood: hdMoodSpecies.contains(kind),
    );
    _bytes += _sizeOf(sheet);
    _ready[key] = sheet;
    if (log) {
      debugPrint('[hd] bake $key ${sheet.cell.toInt()}px x${sheet.image.height ~/ sheet.cell} rows -> ${report()}');
    }
    // 바이트 상한을 넘으면 오래 안 쓴 것부터(방금 구운 것은 남긴다).
    while (_bytes > budget && _ready.length > 1) {
      _evict(except: key);
    }
    return sheet;
  }

  static int _sizeOf(HdSheet s) => s.image.width * s.image.height * 4;

  void clear([double density = 0]) {
    _ready.values.forEach(_retire);
    _ready.clear();
    _used.clear();
    _bytes = 0;
    _density = density;
  }

  void _evict({required String except}) =>
      _drop(_ready.keys.where((k) => k != except).reduce((a, b) => (_used[a] ?? 0) <= (_used[b] ?? 0) ? a : b));

  void _drop(String key) {
    final gone = _ready.remove(key);
    if (gone != null) {
      _bytes -= _sizeOf(gone);
      _retire(gone);
    }
    _used.remove(key);
  }

  /// 장면을 버릴 때(ScenePainter.dispose): 텍스처를 바로 놓는다 — GC에 맡기면 네이티브 메모리가 늦게 풀린다.
  void dispose() {
    clear();
    for (final (s, _) in _retired) {
      s.image.dispose();
    }
    _retired.clear();
    _queue.clear();
  }

  /// 운영자 계측(S1): 캐시 종·칸·행·MB + 버릴 대기 MB + 상한. [log]면 굽을 때마다 debugPrint.
  static bool log = false;
  String report() {
    String mb(int b) => (b / 1048576).toStringAsFixed(1);
    final parts = [
      for (final MapEntry(:key, :value) in _ready.entries)
        '$key ${value.cell.toInt()}px x${value.image.height ~/ value.cell} rows ${mb(_sizeOf(value))}',
    ];
    final wait = _retired.fold(0, (a, r) => a + _sizeOf(r.$1));
    return 'cache ${mb(_bytes)}/${mb(budget)}MB (density ${_density.toStringAsFixed(2)}, cell cap ${_cap.toInt()}) retired ${mb(wait)}MB | ${parts.join(', ')}';
  }

  /// 버릴 대기 바이트(시험).
  int get retiredBytes => _retired.fold(0, (a, r) => a + _sizeOf(r.$1));

  // 밀려난 시트는 바로 버리지 않는다 — 죽는 적 연출이 몇 프레임 더 그 그림을 그린다(버린 그림 그리기 = 단언 실패·release 깨짐).
  final List<(HdSheet, int)> _retired = [];
  // 프레임 수([step]이 매 프레임 센다)로 — sheet() 호출 수로 세면 적이 없을 때 영영 안 버려졌다.
  int _frame = 0;
  void _retire(HdSheet s) => _retired.add((s, _frame));
  void _reap() {
    while (_retired.isNotEmpty && _frame - _retired.first.$2 > 20) {
      _retired.removeAt(0).$1.image.dispose();
    }
  }

  /// 한 종을 8장 × 2방향으로 굽는다(각 칸은 잘라 옆 칸에 번지지 않게).
  /// [moods]면 표정 2행을 더 굽는다. [selfMood]가 아니면(표정을 직접 안 그리는 종) 쓰러짐에 기우뚱·별을 굽기가 얹는다
  /// — 눈은 HdKit.eye가 표정대로(소용돌이·붉은 눈).
  static HdSheet bake(
    HdSpecies sp,
    double world,
    double density, {
    double cap = maxCell,
    bool moods = false,
    bool hits = false,
    bool selfMood = true,
  }) {
    final rows = moods || hits ? 4 : 2;
    // 표정 보스는 4행이라 칸 상한을 한 단계 낮춘다(메모리 2배 → 약 1.1배).
    final cell = (world * density).clamp(16.0, moods ? cap * 0.75 : cap).roundToDouble();
    final r = cell / (2 * sp.extent);
    final rec = PictureRecorder();
    final c = Canvas(rec);
    final k = HdKit();
    for (var f = 0; f < HdKit.frames; f++) {
      for (var row = 0; row < rows; row++) {
        c
          ..save()
          ..clipRect(Rect.fromLTWH(f * cell, row * cell, cell, cell))
          ..translate(f * cell + cell / 2, row * cell + cell / 2);
        if (row.isOdd) c.scale(-1, 1);
        k
          ..mood = row < 2 ? HdMood.idle : (hits ? HdMood.hit : (f < 4 ? HdMood.windup : HdMood.down))
          ..begin(r);
        moods ? k.shadow2(c, r, sp.ground) : k.shadow(c, r, sp.ground); // 보스는 그림자 2단(v2)
        final t = row < 2 || hits ? f * HdKit.loopMs / HdKit.frames : (f % 4) * HdKit.loopMs / 4;
        if (hits && row >= 2) c.scale(1.14, 0.86); // 맞음: 납작 찡긋
        final generic = !selfMood && k.mood == HdMood.down;
        if (generic) k.downTilt(c, r * 0.9, t);
        sp.draw(k, c, r, t);
        if (generic) {
          c.restore();
          k.dizzyStars(c, Offset(0, -r * sp.extent * 0.8), r, t);
        }
        c.restore();
      }
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync((cell * HdKit.frames).toInt(), (cell * rows).toInt());
    pic.dispose();
    return HdSheet(img, cell, world, moods: moods, hits: hits);
  }
}
