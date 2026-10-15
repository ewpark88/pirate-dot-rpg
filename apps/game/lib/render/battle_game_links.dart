part of 'battle_game.dart';

/// UI(S4)가 BattleGame에 넣는 값 — 장면을 새로 만들어도(데모·부하·라이브) 이어진다.
mixin _UiLinks on FlameGame {
  BattleScene get scene;
  bool get _sceneReady;

  Offset? _goldTargetDp;
  void Function(BigNum amount)? _onCoinArrive;
  double _bottomInset = 0;

  /// 상단 바 골드 아이콘 자리 (상자 왼쪽 위 기준 dp, 위면 y < 0) — 코인이 그리로 난다. null이면 배로. UI가 레이아웃마다 넣는다.
  Offset? get goldTargetDp => _goldTargetDp;
  set goldTargetDp(Offset? v) {
    _goldTargetDp = v;
    if (_sceneReady) scene.coinFlow.goldTargetDp = v;
  }

  /// 코인이 목표에 닿은 프레임마다 금액 합계 — UI가 골드 아이콘을 통통 튀기고 '+금액'을 띄운다.
  void Function(BigNum amount)? get onCoinArrive => _onCoinArrive;
  set onCoinArrive(void Function(BigNum amount)? f) {
    _onCoinArrive = f;
    if (_sceneReady) scene.coinFlow.onCoinArrive = f;
  }

  /// 도크·시트가 상자 아래를 가리는 높이 (dp, S4가 레이아웃·시트 애니메이션 때마다 넣는다). 선원 줄·필드가 그 위로.
  double get bottomInset => _bottomInset;
  set bottomInset(double v) {
    if (v == _bottomInset) return;
    _bottomInset = v;
    if (hasLayout) onGameResize(size);
  }
}
