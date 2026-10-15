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

  final Set<String> _made = {};
  String? _loading;

  /// 스킨 사본이 준비됐는가 — 준비되면 스프라이트 키 `<key>@<skinId>`로 은행에 들어 있다.
  bool ready(String skinId) => _made.contains(skinId);

  /// [skin] = {hull: [...], sail: [...], flag: [...]} 색 문자열. 이미 만들었거나 만드는 중이면 그대로.
  Future<void> prepare(String skinId, JsonReader skin, SpriteBank bank, Iterable<String> keys) async {
    if (_made.contains(skinId) || _loading == skinId) return;
    _loading = skinId;
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
    for (final key in keys) {
      final s = bank[key];
      if (s == null) continue;
      bank.put('$key@$skinId', await recolor(s.image, map), frames: s.frames);
    }
    _made.add(skinId);
    _loading = null;
  }

  /// [src]의 RGB가 [map]에 있으면 바꾼 사본 (알파 그대로).
  static Future<ui.Image> recolor(ui.Image src, Map<int, int> map) async {
    final data = (await src.toByteData())!.buffer.asUint8List();
    final px = Uint8List.fromList(data);
    for (var i = 0; i < px.length; i += 4) {
      if (px[i + 3] == 0) continue;
      final to = map[(px[i] << 16) | (px[i + 1] << 8) | px[i + 2]];
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
