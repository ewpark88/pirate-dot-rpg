part of 'hd_impact.dart';

/// 착탄 테두리 연출(hd_impact_shapes.dart 300줄 한도로 나눔): 요일 던전 금 테·전설·신화 충격파·신화 무지개 테.
extension _ImpactRims on HdImpact {
  double _ease(double t) => 1 - (1 - t) * (1 - t) * (1 - t);
  double _late(double u) => u < 0.7 ? 1 : (1 - (u - 0.7) / 0.3).clamp(0.0, 1.0);

  /// 요일 던전 그 날 계열: 두꺼운 금 테.
  void _hotRim(Canvas c, double r, double t) {
    _stroke
      ..strokeWidth = r * 0.12 * (1 - t * 0.6)
      ..color = Color.fromRGBO(255, 212, 90, _late(t));
    c.drawCircle(Offset.zero, r * (1 + 0.25 * _ease(t)), _stroke);
  }

  /// 전설·신화 충격파: 착탄 0.2초쯤(t 0.3~)부터 굵은 링이 크게 퍼지며 옅어진다(신화는 보라빛 겹 링).
  void _shockwave(Canvas c, double r, double t, {required bool mythic}) {
    if (t < 0.3) return;
    final k = (t - 0.3) / 0.7;
    final grow = 1 - (1 - k) * (1 - k);
    _stroke
      ..strokeWidth = r * 0.1 * (1 - k) + 0.6
      ..color = Color.fromRGBO(255, 236, 160, 0.85 * (1 - k));
    c.drawCircle(Offset.zero, r * (1 + 0.9 * grow), _stroke);
    if (!mythic) return;
    _stroke.color = Color.fromRGBO(200, 140, 255, 0.6 * (1 - k));
    c.drawCircle(Offset.zero, r * (0.8 + 0.7 * grow), _stroke);
  }

  /// 신화: 무지개 테(색이 돈다).
  void _rainbowRim(Canvas c, double r, double t) {
    _stroke
      ..strokeWidth = r * 0.06
      ..shader = Gradient.sweep(
        Offset.zero,
        const [
          Color(0xFFFF5A5A),
          Color(0xFFFFD45A),
          Color(0xFF5AD86A),
          Color(0xFF4AA8FF),
          Color(0xFFB45AFF),
          Color(0xFFFF5A5A),
        ],
        const [0, 0.2, 0.4, 0.6, 0.8, 1],
      );
    c.drawCircle(Offset.zero, r * (0.9 + 0.3 * _ease(t)), _stroke);
    _stroke.shader = null;
  }
}
