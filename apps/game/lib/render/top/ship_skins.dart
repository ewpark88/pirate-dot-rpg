import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

/// 환생 선박 스킨 (platform-rebirth-v2 §2-2): 그림을 새로 그리지 않고 탑다운 배 층의 정해진 색만 바꾼 사본을 만든다.
/// 사본은 스킨이 바뀔 때 한 번(비동기) — 프레임마다 비용 없음. 색 순서는 tools/art/gen_topdown_ships.py 팔레트:
/// hull = [테두리, 테두리 그늘, 갑판, 갑판 밝은, 판자 틈], sail = [돛, 돛 그늘, 돛 밝은], flag = [망루 깃발].
/// 스킨 값은 계약(rebirth.json skins)이 오기 전까지 fx_map topShip.skinPreview(운영자 미리보기·골든)에서 읽는다.
class ShipSkins {
  static const _hullSrc = [0xFF7A4C28, 0xFF5C381E, 0xFFC4925C, 0xFFD6A870, 0xFFA07042];
  static const _sailSrc = [0xFFF0E8D2, 0xFFCEC2A4, 0xFFFCF8EC];
  static const _flagSrc = [0xFFFFCE3C];
  // 유령 등급(t4) 팔레트와 돛 빨간 줄(3단계↑) — 스킨 v2부터 같은 칸으로 바꾼다.
  static const _hullGhost = [0xFF4E425C, 0xFF382E46, 0xFF685C78, 0xFF7A6E8C, 0xFF544864];
  static const _sailGhost = [0xFF6EDCCD, 0xFF46AAA5, 0xFFAAF5E6];
  static const _stripeSrc = [0xFFD64038];

  final Set<String> _made = {};
  final Map<String, Future<void>> _loading = {};

  /// 지금 스킨의 항적·포구 색(fx_map skinPreview wake·muzzle — 'rainbow'면 무지개). 스킨 없으면 null.
  int? wake;

  /// 이번 프레임에 스킨이 바뀌었나(변신 연출).
  bool changed = false;
  String? _last;
  int? muzzle;
  bool wakeRainbow = false;

  /// 프레임마다(TopScenePainter): 스킨 [id] 사본이 없으면 비동기로 만들기 시작하고, 항적·포구 색을 고른다.
  /// glow 스킨(phantom·ghostship·abyss)이고 준비됐으면 true.
  bool frame(String? id, JsonReader all, SpriteBank? bank, List<String> keys) {
    // 새 배 스킨!(사용자 #8): 스킨이 다른 스킨으로 바뀐 첫 프레임(처음 켤 때는 아님) — 변신 연출 신호.
    changed = _last != null && id != null && id != _last;
    _last = id;
    if (id == null || !all.has(id)) {
      wake = muzzle = null;
      wakeRainbow = false;
      return false;
    }
    final cfg = all.obj(id);
    if (!ready(id) && bank != null) unawaited(prepare(id, cfg, bank, keys));
    int? col(String k) {
      final v = cfg.raw[k];
      return v is String && v != 'rainbow' ? parseArgb(v, 'skin.$k') : null;
    }

    wake = col('wake');
    muzzle = col('muzzle') ?? (cfg.raw['muzzle'] == 'rainbow' ? 0xFFFF5AC8 : null);
    wakeRainbow = cfg.raw['wake'] == 'rainbow';
    return cfg.raw['glow'] == true && ready(id);
  }

  /// 스킨 사본이 준비됐는가 — 준비되면 스프라이트 키 `<key>@<skinId>`로 은행에 들어 있다.
  bool ready(String skinId) => _made.contains(skinId);

  /// [skin] = {hull: [...], sail: [...], flag: [...]} 색 문자열. 이미 만들었거나 만드는 중이면 그대로.
  Future<void> prepare(String skinId, JsonReader skin, SpriteBank bank, Iterable<String> keys) async {
    // 같은 스킨을 동시에 부르면(배 탭 미리보기 여러 칸) 먼저 시작한 굽기를 같이 기다린다 — 예전엔 바로 돌아가
    // 그 칸이 기본 배 색으로 남았다(S4 신고).
    if (_made.contains(skinId)) return;
    final going = _loading[skinId];
    if (going != null) return going;
    await (_loading[skinId] = _make(skinId, skin, bank, keys));
    _loading.removeWhere((k, _) => k == skinId);
  }

  Future<void> _make(String skinId, JsonReader skin, SpriteBank bank, Iterable<String> keys) async {
    final map = <int, int>{};
    void pair(List<int> src, String part) {
      if (!skin.has(part)) return;
      final dst = [for (final c in skin.strs(part)) parseArgb(c, 'skin.$part')];
      for (var i = 0; i < src.length && i < dst.length; i++) {
        map[src[i] & 0xFFFFFF] = dst[i] & 0xFFFFFF;
      }
    }

    pair(_hullSrc, 'hull');
    pair(_sailSrc, 'sail');
    pair(_flagSrc, 'flag');
    // 스킨 v2(stripe 키가 있는 7종)만 유령 등급 팔레트·돛 빨간 줄까지 바꾼다 — 기존 4종 그림은 그대로.
    if (skin.has('stripe')) {
      pair(_hullGhost, 'hull');
      pair(_sailGhost, 'sail');
      pair(_stripeSrc, 'stripe');
    }
    final pattern = patternOf(skin);
    for (final key in keys) {
      final s = bank[key];
      if (s == null) continue;
      bank.put('$key@$skinId', await recolor(s.image, map, pattern: pattern), frames: s.frames);
    }
    _made.add(skinId);
  }

  /// 스킨 무늬(배 스킨 v2, 사용자 #8): rainbowSail = 돛을 줄마다 무지개로(돛 그늘·밝은 색은 어둡게·밝게),
  /// speckle = [{on: hull|sail, color, every}] 그 부위 픽셀을 결정론 해시로 every칸에 하나씩 점(용암 금·서리·물방울 무늬).
  static SkinPattern? patternOf(JsonReader skin) {
    final rainbow = skin.raw['rainbowSail'] == true;
    final sp = (skin.raw['speckle'] as List?) ?? const [];
    if (!rainbow && sp.isEmpty) return null;
    return (
      rainbowSail: rainbow,
      speckle: [
        for (final m in sp.cast<Map<String, dynamic>>())
          (
            on: {for (final c in (m['on'] == 'sail' ? _sailSrc : _hullSrc)) c & 0xFFFFFF},
            color: parseArgb(m['color'] as String, 'skin.speckle') & 0xFFFFFF,
            every: (m['every'] as num).toInt(),
          ),
      ],
    );
  }

  static const _rainbow = [0xFF4A4A, 0xFFA03A, 0xFFE24A, 0x5AD85A, 0x4AB8FF, 0x9A6AFF];

  /// [src]의 RGB가 [map]에 있으면 바꾼 사본 (알파 그대로). [pattern]이 있으면 바꾸기 전 원래 색 기준으로 무늬를 먼저.
  static Future<ui.Image> recolor(ui.Image src, Map<int, int> map, {SkinPattern? pattern}) async {
    final data = (await src.toByteData())!.buffer.asUint8List();
    final px = Uint8List.fromList(data);
    final w = src.width;
    for (var i = 0; i < px.length; i += 4) {
      if (px[i + 3] == 0) continue;
      final rgb = (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
      int? to;
      if (pattern != null) {
        final x = (i ~/ 4) % w;
        final y = (i ~/ 4) ~/ w;
        if (pattern.rainbowSail) {
          var k = _sailSrc.indexWhere((c) => c & 0xFFFFFF == rgb);
          if (k < 0) k = _sailGhost.indexWhere((c) => c & 0xFFFFFF == rgb);
          if (k >= 0) {
            final base = _rainbow[(y ~/ 3) % _rainbow.length];
            to = k == 1 ? _shade(base, 0.72) : (k == 2 ? _shade(base, 1.25) : base);
          }
        }
        for (final sp in pattern.speckle) {
          if (sp.on.contains(rgb) && (((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF) % sp.every == 0) to = sp.color;
        }
      }
      to ??= map[rgb];
      if (to == null) continue;
      px[i] = (to >> 16) & 0xFF;
      px[i + 1] = (to >> 8) & 0xFF;
      px[i + 2] = to & 0xFF;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(px);
    final desc = ui.ImageDescriptor.raw(
      buffer,
      width: src.width,
      height: src.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await desc.instantiateCodec();
    return (await codec.getNextFrame()).image;
  }
}

/// 스킨 무늬 — [ShipSkins.patternOf].
typedef SkinPattern = ({bool rainbowSail, List<({Set<int> on, int color, int every})> speckle});

int _shade(int rgb, double k) {
  int ch(int v) => (v * k).round().clamp(0, 255);
  return ch((rgb >> 16) & 0xFF) << 16 | ch((rgb >> 8) & 0xFF) << 8 | ch(rgb & 0xFF);
}
