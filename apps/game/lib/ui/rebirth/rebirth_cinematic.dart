import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/ship/ship_look.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

// 환생 연출 (S1 2026-10-18): [환생] 확정 순간 2.8초 — 화면이 금빛으로 감기고(가운데서 퍼지는 원) · 지도 조각이 하늘에서 쏟아지며
// '보물지도 +n' · 배가 새 돛을 달고 왼쪽에서 들어와 '다시 출항!' · 환생 보상(젬·소환·스킨·칭호) 카드가 차례로. 탭하면 끝까지
// 넘기고, 다 보이면 한 번 더 탭(또는 0.6초 뒤 저절로) 닫혀 상자 창으로 이어진다. 애니메이션 줄이기면 건너뛴다.

/// 연출 2.8초 + 다 보인 채 0.6초 머문 뒤 저절로 닫힌다(타이머 대신 한 컨트롤러 — 시험 pumpAndSettle이 끝까지 간다).
const _length = Duration(milliseconds: 3400);

/// 조각 몇 개를 떨어뜨리나(그림 수 — 실제 조각 수와 상관없이 많아 보이게, 위로 18).
const _pieceSprites = 18;

/// 연출을 띄우고 끝나면 돌아온다. 애니메이션 줄이기면 바로.
Future<void> showRebirthCinematic(BuildContext context, {required int pieces, required ChestVm chest}) {
  if (MediaQuery.disableAnimationsOf(context)) return Future.value();
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => RebirthCinematic(pieces: pieces, chest: chest),
    ),
  );
}

class RebirthCinematic extends StatefulWidget {
  const RebirthCinematic({required this.pieces, required this.chest, super.key});

  final int pieces;
  final ChestVm chest;

  @override
  State<RebirthCinematic> createState() => _RebirthCinematicState();
}

class _RebirthCinematicState extends State<RebirthCinematic> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _length);

  @override
  void initState() {
    super.initState();
    unawaited(_c.forward().then((_) => _done()));
  }

  void _done() {
    if (mounted) Navigator.of(context).pop();
  }

  /// 첫 탭: 다 보인 자리(2.8초)로 넘김, 그 뒤 탭: 닫기.
  void _tap() => _c.value * _secs >= 2.8 ? _done() : _c.value = 2.8 / _secs;

  static final double _secs = _length.inMilliseconds / 1000;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// [from]~[to] 초 사이 0→1.
  double _span(double from, double to) => ((_c.value * _secs - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = <(Widget, String)>[
      if (widget.chest.gems > 0) (const SkinIcon(UiSprites.gem, size: 34), l10n.uiRebirthCineGems(widget.chest.gems)),
      if (widget.chest.summons > 0)
        (const SkinIcon(UiSprites.star, size: 34), l10n.uiRebirthCineSummons(widget.chest.summons)),
      if (widget.chest.skin != null)
        (
          ShipLookPreview(useSkin: true, skin: widget.chest.skin, size: 44),
          l10n.uiRebirthChestSkin(skinName(l10n, widget.chest.skin!)),
        ),
      if (widget.chest.title != null)
        (const SkinIcon(UiSprites.star, size: 34), l10n.uiRebirthChestTitle(titleName(l10n, widget.chest.title!))),
    ];
    return GestureDetector(
      key: const Key('rebirth.cine'),
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final wipe = Curves.easeIn.transform(_span(0, 0.5));
          final fall = _span(0.4, 1.5);
          final sail = Curves.easeOutCubic.transform(_span(1.3, 2.1));
          return LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;
              final double ship = math.min(w * 0.4, 240);
              return Stack(
                children: [
                  // 금빛 감김: 가운데서 퍼지는 원(색 알파로 — 화면 전체 Opacity 층을 만들지 않게).
                  Positioned.fill(child: CustomPaint(painter: _GoldWipe(wipe))),
                  // 지도 조각 비.
                  for (var i = 0; i < _pieceSprites; i++)
                    if (fall > 0 && fall < 1) _piece(i, fall, w, h),
                  if (fall > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: h * 0.16,
                      child: Center(
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * Curves.elasticOut.transform(math.min(1, fall * 1.6)),
                          child: OutlineText(
                            l10n.uiRebirthCineMap(widget.pieces),
                            key: const Key('rebirth.cine.map'),
                            size: 30,
                            tone: OutlineTone.gold,
                          ),
                        ),
                      ),
                    ),
                  // 새 돛 단 배가 왼쪽에서 들어와 가운데에 선다.
                  if (sail > 0)
                    Positioned(
                      left: -ship + (w / 2 + ship / 2) * sail,
                      top: h * 0.27 + math.sin(_c.value * 22) * 3,
                      // 위에서 본 배(뱃머리 위) → 오른쪽을 보게 돌려 왼쪽에서 들어온다.
                      child: Transform.rotate(
                        angle: math.pi / 2,
                        child: ShipLookPreview(
                          useSkin: widget.chest.skin != null,
                          skin: widget.chest.skin,
                          size: ship,
                        ),
                      ),
                    ),
                  if (sail >= 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: h * 0.27 + ship + 6,
                      child: Center(
                        child: OutlineText(
                          l10n.uiRebirthCineSail,
                          key: const Key('rebirth.cine.sail'),
                          size: 28,
                        ),
                      ),
                    ),
                  // 보상 카드: 2.0초부터 0.2초 간격으로 튀어오른다.
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: h * 0.08 + 28,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, c) in cards.indexed)
                          if (_span(2.0 + 0.2 * i, 2.3 + 0.2 * i) case final k when k > 0)
                            Transform.scale(
                              scale: Curves.easeOutBack.transform(k),
                              child: _Card(key: Key('rebirth.cine.card.$i'), icon: c.$1, text: c.$2),
                            ),
                      ],
                    ),
                  ),
                  if (wipe >= 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: h * 0.04,
                      child: Text(
                        l10n.uiRebirthCineTap,
                        textAlign: TextAlign.center,
                        style: Skin.text(13, color: const Color(0xCC5A3A00)),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// 조각 하나: 자리·늦춤·회전은 번호로 정한다(매번 같은 그림).
  Widget _piece(int i, double fall, double w, double h) {
    final r = math.Random(i * 7919 + 13);
    final delay = r.nextDouble() * 0.4;
    final k = ((fall - delay) / (1 - delay)).clamp(0.0, 1.0);
    final x = w * (0.08 + 0.84 * r.nextDouble());
    final y = -40 + (h * 0.55) * Curves.easeIn.transform(k);
    return Positioned(
      left: x - 16,
      top: y,
      child: Transform.rotate(
        angle: (r.nextDouble() - 0.5) * 2 + k * 4 * (r.nextBool() ? 1 : -1),
        child: const SkinIcon(UiSprites.tabMap, size: 32),
      ),
    );
  }
}

class _GoldWipe extends CustomPainter {
  _GoldWipe(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final c = size.center(Offset.zero);
    final r = size.longestSide * 0.8 * t;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF3B0), Color(0xFFFFD84A), Color(0xFFE8A92A)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: math.max(1, r))),
    );
  }

  @override
  bool shouldRepaint(_GoldWipe old) => old.t != t;
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.text, super.key});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 200),
    padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
    decoration: BoxDecoration(
      color: Skin.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFB8860B), width: 2),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: Skin.bold(13))),
      ],
    ),
  );
}
