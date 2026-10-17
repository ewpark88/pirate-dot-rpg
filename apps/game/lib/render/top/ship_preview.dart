import 'dart:async';

import 'package:flame/cache.dart';
import 'package:flutter/widgets.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/hd/hd_ship.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/render/top/ship_skins.dart';
import 'package:pirate_dot/render/top/top_ship_painter.dart';

/// 탑다운 배 그림 위젯 (S4: 배 탭 '지금 배' 큰 미리보기·부위별 '다음 외형' 작은 미리보기·ShipLookChanged 축하 팝업·스킨 고르기).
/// 전장과 같은 층 그림(TopShipPainter)·같은 스킨 색 바꾸기(ShipSkins)를 쓴다. 뱃머리가 위, [size] 정사각 안에 맞춰 도트 정수배.
///
/// - [tier] = 배 등급 id(ship_tiers.json, 예 'sloop'), [look] = 부위 → 단계(BattleView.shipLook과 같음, 0 = 1단계 그림).
/// - [skin] = 스킨 id, [skinPalette] = {hull:[...], sail:[...], flag:[...]} 색(계약 전에는 fx_map topShip.skinPreview[skin]).
/// - [glowPart]·[glow] = 축하 팝업에서 그 부위를 흰빛으로(0~1).
class ShipPreview extends StatefulWidget {
  const ShipPreview({
    required this.tables,
    required this.tier,
    required this.look,
    this.skin,
    this.skinPalette,
    this.size = 160,
    this.glowPart,
    this.glow = 0,
    super.key,
  });

  final GameTables tables;
  final String tier;
  final Map<String, int> look;
  final String? skin;
  final JsonReader? skinPalette;
  final double size;
  final String? glowPart;
  final double glow;

  @override
  State<ShipPreview> createState() => _ShipPreviewState();

  /// 미리 읽기(앱 시작·테스트): 배 층 은행과 [skins] 스킨 사본을 준비한다. 준비된 뒤에는 위젯이 바로 그린다.
  static Future<void> preload(GameTables tables, {Map<String, JsonReader> skins = const {}}) async {
    final bank = await (_bank ??= SpriteBank.load(Images(prefix: 'assets/'), tables, only: 'td:'));
    _ready = bank;
    for (final MapEntry(key: id, value: palette) in skins.entries) {
      await _skins.prepare(id, palette, bank, _keys(tables));
    }
  }
}

List<String> _keys(GameTables t) => [
  for (final tier in t.shipTiers.tiers)
    for (final l in TopShipPainter.layers) 'td:${tier.id}:$l',
];

/// 미리보기 전용 작은 은행(td: 배 층만) — 앱에서 한 번 읽어 모든 미리보기가 같이 쓴다.
Future<SpriteBank>? _bank;
SpriteBank? _ready;
final _skins = ShipSkins();

class _ShipPreviewState extends State<ShipPreview> {
  SpriteBank? _loaded = _ready;

  @override
  void initState() {
    super.initState();
    HdShip.load(widget.tables.fxMap.raw.obj('topShip').obj('skinPreview')); // HD 배 스킨 색
    final skin = widget.skin;
    if (_loaded == null || (skin != null && !_skins.ready(skin))) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ShipPreview old) {
    super.didUpdateWidget(old);
    if (old.skin != widget.skin) unawaited(_load());
  }

  Future<void> _load() async {
    final bank = await (_bank ??= SpriteBank.load(Images(prefix: 'assets/'), widget.tables, only: 'td:'));
    _ready = bank;
    final skin = widget.skin;
    final palette = widget.skinPalette;
    if (skin != null && palette != null) {
      await _skins.prepare(skin, palette, bank, _keys(widget.tables));
    }
    if (mounted) setState(() => _loaded = bank);
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: _loaded == null
        ? null
        : CustomPaint(
            painter: _ShipPainter(
              TopShipPainter(SpriteDraw()..bank = _loaded),
              widget.tier,
              widget.look,
              widget.skin != null && _skins.ready(widget.skin!) ? widget.skin : null,
              widget.glowPart,
              widget.glow,
              MediaQuery.devicePixelRatioOf(context),
            ),
          ),
  );
}

class _ShipPainter extends CustomPainter {
  _ShipPainter(this.ship, this.tier, this.look, this.skin, this.glowPart, this.glow, this.dpr);

  final TopShipPainter ship;
  final String tier;
  final Map<String, int> look;
  final String? skin;
  final String? glowPart;
  final double glow;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = ship.sizeOf(tier);
    if (frame == null) return;
    // 칸에 꽉 맞춘다. 정수 물리 픽셀 배율이 3배 이상이면 그쪽(도트 선명), 작은 칸은 꽉 맞춤 우선(크기가 칸마다 같게).
    final fit = size.height * 0.96 * dpr / frame.height;
    final k = (fit >= 3 ? fit.floorToDouble() : fit) / dpr;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(k);
    ship.paint(canvas, tier, look, skin: skin, glowPart: glowPart, glow: glow);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShipPainter old) =>
      old.tier != tier || old.look != look || old.skin != skin || old.glow != glow || old.glowPart != glowPart;
}
