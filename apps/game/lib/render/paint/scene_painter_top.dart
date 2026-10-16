part of 'scene_painter.dart';

/// 탑다운 그리기 (같은 라이브러리 — ScenePainter의 비공개 그리기를 쓴다).
extension TopPaint on ScenePainter {
  /// 탑다운(T2, BattleView.mode 'top'): 상자 dp 캔버스. 전장은 탑다운 카메라, 덮개·HUD·선원 줄은 옆모습 배치(같은 상자)로.
  void paintTop(Canvas canvas, TopFrame frame) {
    _numberScale = scene.layout.dot / frame.dot;
    // 이펙트는 배가 작아진 탑다운(가로 270)에서 배 대비 과하지 않게 한 번 더 줄인다(사용자 '거슬린다').
    _fxScale = _numberScale * 0.7;
    scene.topHits.sprites ??= _sprite;
    _pb
      ..unitDp = frame.dot
      ..fever = top.fever.level;
    top.paint(canvas, frame, _worldFx);
    final l = scene.layout;
    canvas
      ..save()
      ..scale(l.dot)
      ..translate(-l.viewDots.left, -l.viewDots.top);
    _stage.paintOverlays(canvas);
    _hud
      ..paintHud(canvas, top: true)
      ..paintSlots(canvas);
    canvas.restore();
  }
}
