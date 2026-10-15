import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 시험판 그림: 위에서 내려다본 도트를 코드로 그린다(무료·라이선스 없음). 색은 기존 적 그림(enemies/*.png)과 같은 팔레트.
/// 글자 하나 = 도트 하나, '.' = 투명. 모두 위쪽을 바라본다(배·물고기는 진행 방향으로 돌려 그린다).
const _palette = <String, int>{
  'o': 0xFF1B1726, // 외곽선 (27,23,38)
  'w': 0xFFF5F5FA, // 흰 점·돛
  // 배
  'h': 0xFF8B5A2B, // 선체
  'H': 0xFF6B4220, // 선체 그늘
  'd': 0xFFC9925A, // 갑판
  's': 0xFFEDE6D6, // 돛(위에서 본 가로 막대)
  'm': 0xFF4A3018, // 돛대
  'f': 0xFFD94040, // 깃발
  'c': 0xFF3A3A44, // 대포
  // 게 (150,40,40)·(220,70,60)
  'R': 0xFF962828,
  'r': 0xFFDC463C,
  // 해파리 (180,90,170)·(240,140,200)
  'P': 0xFFB45AAA,
  'p': 0xFFF08CC8,
  // 물고기 (60,120,60)·(110,190,90)
  'G': 0xFF3C783C,
  'g': 0xFF6EBE5A,
  // 금화
  'y': 0xFFF2C94C,
  'Y': 0xFFB8862A,
};

const shipArt = [
  '.....f.....',
  '....of.....',
  '....omo....',
  '...oddo....',
  '..oddddo...',
  '.ossssssso.',
  'oswssssswso',
  '.ossssssso.',
  '.ohdddddho.',
  'ochdddddhco',
  '.ohddmddho.',
  'ochdddddhco',
  '.ossssssso.',
  'oswssssswso',
  '.ossssssso.',
  '.ohdddddho.',
  '.oHhdddhHo.',
  '..oHhhhHo..',
  '...oHHHo...',
  '....ooo....',
];

const crabArt = [
  'oo.......oo',
  'orro...orro',
  '.oro...oro.',
  '..orrrrro..',
  '.orwrrrwro.',
  'orrRrrrRrro',
  '.orrRRRrro.',
  'o.oRRRRRo.o',
  '.o.o...o.o.',
];

const jellyArt = [
  '..ooooo..',
  '.oppppwo.',
  'oppppppwo',
  'opPppppPo',
  'opppPpppo',
  'oPpppppPo',
  '.oPPPPPo.',
  '..ooooo..',
  '.p.p.p.p.',
  'p.p.p.p.p',
];

const fishArt = [
  '..oo..',
  '.oggo.',
  'ogwwgo',
  'oggggo',
  'oGggGo',
  'ogGGgo',
  '.oggo.',
  '.oGGo.',
  '..oo..',
  '.oGGo.',
  'oG..Go',
];

const coinArt = ['.yy.', 'yYyy', 'yyYy', '.yy.'];

/// 피해 숫자 3×5(외곽선 1도트를 둘러 5×7).
const _digits = [
  ['www', 'w.w', 'w.w', 'w.w', 'www'],
  ['.w.', 'ww.', '.w.', '.w.', 'www'],
  ['www', '..w', 'www', 'w..', 'www'],
  ['www', '..w', 'www', '..w', 'www'],
  ['w.w', 'w.w', 'www', '..w', '..w'],
  ['www', 'w..', 'www', '..w', 'www'],
  ['www', 'w..', 'www', 'w.w', 'www'],
  ['www', '..w', '..w', '.w.', '.w.'],
  ['www', 'w.w', 'www', 'w.w', 'www'],
  ['www', 'w.w', 'www', '..w', 'www'],
];

/// 그림을 한 장(아틀라스)에 모은다 — 한 번의 drawAtlas로 수백 개를 그리기 위해.
class ProtoAtlas {
  ProtoAtlas._(this.image, this.rects);

  final ui.Image image;
  final Map<String, ui.Rect> rects;

  ui.Rect rect(String id) => rects[id]!;

  static Future<ProtoAtlas> build() async {
    final sprites = <String, List<String>>{
      'ship': shipArt,
      'crab': crabArt,
      'jelly': jellyArt,
      'fish': fishArt,
      'coin': coinArt,
      for (var i = 0; i < 10; i++) 'd$i': _outlined(_digits[i]),
      // 맞았을 때 번쩍임용 흰 실루엣(색 섞기 대신 그림으로 — drawAtlas 섞기는 투명 칸까지 칠했다)
      for (final id in ['ship', 'crab', 'jelly', 'fish']) '${id}_w': _silhouette(_art[id]!),
    };
    // 가로로 1도트 간격을 두고 늘어놓는다.
    var width = 0;
    var height = 0;
    final at = <String, (int, int, int, int)>{};
    for (final e in sprites.entries) {
      final w = e.value.first.length;
      final h = e.value.length;
      at[e.key] = (width, 0, w, h);
      width += w + 1;
      if (h > height) height = h;
    }
    final px = Uint8List(width * height * 4);
    for (final e in sprites.entries) {
      final (ox, oy, _, _) = at[e.key]!;
      for (var y = 0; y < e.value.length; y++) {
        final row = e.value[y];
        for (var x = 0; x < row.length; x++) {
          final c = _palette[row[x]];
          if (c == null) continue;
          final i = ((oy + y) * width + ox + x) * 4;
          px[i] = (c >> 16) & 0xFF;
          px[i + 1] = (c >> 8) & 0xFF;
          px[i + 2] = c & 0xFF;
          px[i + 3] = (c >> 24) & 0xFF;
        }
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, width, height, ui.PixelFormat.rgba8888, done.complete);
    final image = await done.future;
    return ProtoAtlas._(image, {
      for (final e in at.entries)
        e.key: ui.Rect.fromLTWH(
          e.value.$1.toDouble(),
          e.value.$2.toDouble(),
          e.value.$3.toDouble(),
          e.value.$4.toDouble(),
        ),
    });
  }

  static const Map<String, List<String>> _art = {'ship': shipArt, 'crab': crabArt, 'jelly': jellyArt, 'fish': fishArt};

  /// 보이는 도트를 모두 흰색으로.
  static List<String> _silhouette(List<String> art) => [
    for (final row in art) row.split('').map((c) => c == '.' ? '.' : 'w').join(),
  ];

  /// 흰 숫자 둘레에 외곽선 1도트.
  static List<String> _outlined(List<String> g) {
    const w = 5;
    const h = 7;
    final out = List.generate(h, (_) => List.filled(w, '.'));
    for (var y = 0; y < g.length; y++) {
      for (var x = 0; x < g[y].length; x++) {
        if (g[y][x] != 'w') continue;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final yy = y + 1 + dy;
            final xx = x + 1 + dx;
            if (out[yy][xx] == '.') out[yy][xx] = 'o';
          }
        }
      }
    }
    for (var y = 0; y < g.length; y++) {
      for (var x = 0; x < g[y].length; x++) {
        if (g[y][x] == 'w') out[y + 1][x + 1] = 'w';
      }
    }
    return [for (final r in out) r.join()];
  }
}
