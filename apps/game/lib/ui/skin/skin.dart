import 'package:flutter/material.dart';

/// 스킨 k1 (디자인 개편 ①, docs/plans/active/design-kungfu-style.md — 쿵푸할매 서바이버 스타일): 진한 남색·보라 바탕 +
/// 연보라 판에 굵은 검정 외곽선, 입체(베벨·광택) 노랑·초록 버튼, 흰 글씨 + 검은 테두리(외곽선 글자).
/// (r1 파스텔에서 바꿈 — 이름은 그대로 두어 화면 코드가 한 번에 따라온다.) UI의 색·모양·글꼴은 모두 여기서.
abstract final class Skin {
  // ── 바탕·판 ──
  /// 화면 바탕 — 진한 남보라.
  static const sky = Color(0xFF30346B);
  static const skyDeep = Color(0xFF24285A);

  /// 판(카드·창) — 연보라. 진한 글자가 그대로 읽힌다.
  static const card = Color(0xFFDCDCF8);
  static const cream = Color(0xFFE9E7FC);
  static const track = Color(0xFF3B3F74);

  /// 크롬(위 막대·아래 탭·알약) — 짙은 남색 판.
  static const navyPanel = Color(0xFF262A52);
  static const navyPanelTop = Color(0xFF353A70);

  /// 굵은 외곽선 (판·버튼·리본 공통).
  static const outline = Color(0xFF15172E);
  static const outlineWidth = 2.5;

  /// 노란 리본 제목 띠.
  static const ribbonTop = Color(0xFFFFE45C);
  static const ribbonBottom = Color(0xFFFFB80F);

  // ── 글자 ── (흰·크림·하늘 바탕 모두 대비 4.5:1 이상, WCAG)
  static const ink = Color(0xFF1B1D3A);
  static const sub = Color(0xFF474B7C);

  // ── 주 버튼 (초록) ── 흰 외곽선 글자.
  static const primaryTop = Color(0xFF7FD94A);
  static const primaryBottom = Color(0xFF34A52A);
  static const primaryEdge = Color(0xFF1C6516);

  // ── 보상 버튼 (금색) ──
  static const goldTop = Color(0xFFFFE45C);
  static const goldBottom = Color(0xFFFFB30F);
  static const goldEdge = Color(0xFFB36B00);
  static const goldInk = Color(0xFF3B2300);

  // ── 보조 버튼 (흰) ──
  static const plainTop = Color(0xFFF1F0FF);
  static const plainBottom = Color(0xFFC9C7F2);
  static const plainEdge = Color(0xFF6C6EA8);

  // ── 상태 ──
  static const danger = Color(0xFFFF5A6E);
  static const mint = Color(0xFF3CCB8A);

  /// 민트 판 위 글자(순풍·출전) — 대비 4.5:1 이상.
  static const mintInk = Color(0xFF0F5A37);
  static const disabled = Color(0xFF9C9EC4);

  /// 연출 바탕(소환 등)의 짙은 남색.
  static const night = Color(0xFF141A33);

  // ── 모양 ──
  static const radiusCard = 16.0;
  static const radiusButton = 14.0;

  /// 통통한 버튼의 아래 테두리 두께.
  static const buttonEdge = 4.0;

  static const shadowColor = Color(0x5510122A);
  static const List<BoxShadow> shadow = [BoxShadow(color: shadowColor, blurRadius: 10, offset: Offset(0, 3))];
  static const List<BoxShadow> shadowSmall = [BoxShadow(color: shadowColor, blurRadius: 6, offset: Offset(0, 2))];

  // ── 스킨 r2 깊이감 (docs/specs/ui-skin-r2.md ①) ──
  /// 판 위→아래 그라데이션 아래쪽 색(흰 판), 판 아래 진한 테두리, 안쪽 위 하이라이트.
  static const cardBottom = Color(0xFFC6C7EF);
  static const Color cardEdge = outline;
  static const Color cardHighlight = outline;

  /// 판 아래 테두리 두께(떠 있는 판).
  static const cardEdgeWidth = 3.0;

  /// 두 겹 그림자: 넓게 흐린 것 + 바로 아래 진한 것.
  static const List<BoxShadow> shadowDepth = [
    BoxShadow(color: Color(0x4010122A), blurRadius: 14, offset: Offset(0, 5)),
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

  /// 외곽선 글자 (흰 글씨 + 검은 테두리): 여덟 방향 그림자로 테두리를 그린다.
  static TextStyle outlined(double size, {Color color = Colors.white, double stroke = 1.6}) => text(
    size,
    color: color,
  ).copyWith(shadows: outlineShadows(stroke));

  static List<Shadow> outlineShadows(double stroke) => [
    for (final (dx, dy) in const [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)])
      Shadow(color: outline, offset: Offset(dx * stroke, dy * stroke)),
    Shadow(color: outline, offset: Offset(0, stroke + 1)),
  ];
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
            // k1: 굵은 검정 외곽선 (색 테두리를 주면 그 색).
            border: Border.all(
              color: border ?? Skin.outline,
              width: border == null ? Skin.outlineWidth : borderWidth + 1,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 둥근 알약 진행 막대 (k1: 짙은 홈 + 굵은 외곽선, 채움은 같은 색 밝기 그라데이션 + 위 광택).
class SkinBar extends StatelessWidget {
  const SkinBar({required this.value, this.color = Skin.mint, this.height = 10, super.key});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Skin.track,
      borderRadius: BorderRadius.circular(height),
      border: Border.all(color: Skin.outline, width: height >= 8 ? 2 : 1.2),
    ),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: value.clamp(0, 1).toDouble(),
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Skin.outline, 0.15)!],
          ),
          borderRadius: BorderRadius.circular(height),
        ),
      ),
    ),
  );
}
