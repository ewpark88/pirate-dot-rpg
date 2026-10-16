import 'package:flutter/material.dart';

/// 스킨 r1 (docs/specs/ui-skin-r1.md, 사용자 승인 2026-10-15): 바다 파스텔 바탕 + 선명한 강조, 둥근 모서리·부드러운 그림자.
/// UI의 색·모양·글꼴은 모두 여기서. (전장 도트는 렌더 몫이라 그대로.)
abstract final class Skin {
  // ── 바탕·판 ──
  static const sky = Color(0xFFDDF2FF);
  static const skyDeep = Color(0xFFB9E3FF);
  static const card = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFFFAF0);
  static const track = Color(0xFFE3ECF7);

  // ── 글자 ── (흰·크림·하늘 바탕 모두 대비 4.5:1 이상, WCAG)
  static const ink = Color(0xFF2B3A55);
  static const sub = Color(0xFF56657F);

  // ── 주 버튼 (파랑) ── 흰 글자가 위쪽 밝은 곳에서도 4.5:1 이상.
  static const primaryTop = Color(0xFF1E6FD6);
  static const primaryBottom = Color(0xFF1460C4);
  static const primaryEdge = Color(0xFF0D4A9E);

  // ── 보상 버튼 (금색) ──
  static const goldTop = Color(0xFFFFE27A);
  static const goldBottom = Color(0xFFFFB31F);
  static const goldEdge = Color(0xFFD98A00);
  static const goldInk = Color(0xFF6A3C00);

  // ── 보조 버튼 (흰) ──
  static const plainTop = Color(0xFFFFFFFF);
  static const plainBottom = Color(0xFFEAF3FC);
  static const plainEdge = Color(0xFFB9C6DA);

  // ── 상태 ──
  static const danger = Color(0xFFFF5A6E);
  static const mint = Color(0xFF3CCB8A);

  /// 민트 판 위 글자(순풍·출전) — 대비 4.5:1 이상.
  static const mintInk = Color(0xFF146A43);
  static const disabled = Color(0xFFC9D3E2);

  /// 연출 바탕(소환 등)의 짙은 남색.
  static const night = Color(0xFF141A33);

  // ── 모양 ──
  static const radiusCard = 16.0;
  static const radiusButton = 14.0;

  /// 통통한 버튼의 아래 테두리 두께.
  static const buttonEdge = 4.0;

  static const shadowColor = Color(0x2E1E3C78);
  static const List<BoxShadow> shadow = [BoxShadow(color: shadowColor, blurRadius: 10, offset: Offset(0, 3))];
  static const List<BoxShadow> shadowSmall = [BoxShadow(color: shadowColor, blurRadius: 6, offset: Offset(0, 2))];

  // ── 스킨 r2 깊이감 (docs/specs/ui-skin-r2.md ①) ──
  /// 판 위→아래 그라데이션 아래쪽 색(흰 판), 판 아래 진한 테두리, 안쪽 위 하이라이트.
  static const cardBottom = Color(0xFFF3F8FF);
  static const cardEdge = Color(0xFFD3E1F3);
  static const cardHighlight = Color(0xCCFFFFFF);

  /// 판 아래 테두리 두께(떠 있는 판).
  static const cardEdgeWidth = 3.0;

  /// 두 겹 그림자: 넓게 흐린 것 + 바로 아래 진한 것.
  static const List<BoxShadow> shadowDepth = [
    BoxShadow(color: Color(0x241E3C78), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x141E3C78), blurRadius: 3, offset: Offset(0, 1)),
  ];

  // ── 글꼴 ── Jua(OFL) + Jua에 없는 기호(· × → … 등)는 Gowun Dodum 서브셋(OFL).
  static const font = 'Jua';
  static const fontFallback = ['GowunDodumSymbols'];

  /// 본문 16, 작은 설명 14, 제목 20, 큰 숫자 22+.
  static TextStyle text(double size, {Color color = ink, FontWeight weight = FontWeight.normal}) => TextStyle(
    fontFamily: font,
    fontFamilyFallback: fontFallback,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.2,
  );
}

/// 흰/크림 판 카드 (스킨 r2 깊이감 — [SkinDepth]).
class SkinCard extends StatelessWidget {
  const SkinCard({required this.child, this.color = Skin.card, this.padding = const EdgeInsets.all(14), super.key});

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SkinDepth(fill: color, padding: padding, child: child);
}

/// 떠 있는 판 (스킨 r2 ①): 아래 진한 테두리 + 위→아래 그라데이션 + 안쪽 위 하이라이트 + 두 겹 그림자.
/// [fill]이 흰 판이면 연하늘로 내려가는 그라데이션, 다른 색이면 그 색에서 살짝 어둡게. [border]를 주면 그 색 테두리.
class SkinDepth extends StatelessWidget {
  const SkinDepth({
    required this.child,
    this.fill = Skin.card,
    this.border,
    this.borderWidth = 1.5,
    this.padding = const EdgeInsets.all(14),
    this.radius = Skin.radiusCard,
    this.shadow = Skin.shadowDepth,
    super.key,
  });

  final Widget child;
  final Color fill;
  final Color? border;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final white = fill == Skin.card;
    final bottom = white ? Skin.cardBottom : Color.lerp(fill, Skin.ink, 0.04)!;
    final edge = border ?? (white ? Skin.cardEdge : Color.lerp(fill, Skin.ink, 0.14)!);
    return DecoratedBox(
      decoration: BoxDecoration(color: edge, borderRadius: BorderRadius.circular(radius), boxShadow: shadow),
      child: Padding(
        padding: const EdgeInsets.only(bottom: Skin.cardEdgeWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [fill, bottom]),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border ?? Skin.cardHighlight, width: border == null ? 1.5 : borderWidth),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 둥근 알약 진행 막대 (채움은 같은 색 밝기 그라데이션).
class SkinBar extends StatelessWidget {
  const SkinBar({required this.value, this.color = Skin.mint, this.height = 10, super.key});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(color: Skin.track, borderRadius: BorderRadius.circular(height)),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: value.clamp(0, 1).toDouble(),
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
          borderRadius: BorderRadius.circular(height),
        ),
      ),
    ),
  );
}
