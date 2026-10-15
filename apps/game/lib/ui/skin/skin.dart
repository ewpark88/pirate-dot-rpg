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

  // ── 글자 ──
  static const ink = Color(0xFF2B3A55);
  static const sub = Color(0xFF7484A3);

  // ── 주 버튼 (파랑) ──
  static const primaryTop = Color(0xFF63C1FF);
  static const primaryBottom = Color(0xFF1F84F2);
  static const primaryEdge = Color(0xFF1565C8);

  // ── 보상 버튼 (금색) ──
  static const goldTop = Color(0xFFFFE27A);
  static const goldBottom = Color(0xFFFFB31F);
  static const goldEdge = Color(0xFFD98A00);
  static const goldInk = Color(0xFF7A4600);

  // ── 보조 버튼 (흰) ──
  static const plainTop = Color(0xFFFFFFFF);
  static const plainBottom = Color(0xFFEAF3FC);
  static const plainEdge = Color(0xFFB9C6DA);

  // ── 상태 ──
  static const danger = Color(0xFFFF5A6E);
  static const mint = Color(0xFF3CCB8A);
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

/// 흰/크림 판 카드.
class SkinCard extends StatelessWidget {
  const SkinCard({required this.child, this.color = Skin.card, this.padding = const EdgeInsets.all(14), super.key});

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(Skin.radiusCard),
      boxShadow: Skin.shadow,
    ),
    child: Padding(padding: padding, child: child),
  );
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
          borderRadius: BorderRadius.circular(height),
        ),
      ),
    ),
  );
}
