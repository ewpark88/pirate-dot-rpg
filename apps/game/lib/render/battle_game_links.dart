part of 'battle_game.dart';

/// UI(S4)가 BattleGame에 넣는 값 — 장면을 새로 만들어도(데모·부하·라이브) 이어진다.
mixin _UiLinks on FlameGame {
  BattleScene get scene;
  bool get _sceneReady;
  ScenePainter get painter;

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

  /// 탑다운: 전장 좌표 ↔ 상자 dp (UI 탭 판정용 — 황금 물고기·보물상자, 시트를 끄는 중에도 지금 배치 기준).
  // 카메라 = 바다 가운데(피버 좌우 이동 때도 고정) — 그리기와 같은 기준.
  /// 탑다운 화면 문구(빠른 항해 돌파 컷인·스탬프) — UI가 AppLocalizations로 채운다.
  set topTexts(TopTexts v) {
    scene.topHits.fast.texts = v;
    scene.topHits.bounty
      ..wanted = v.wanted
      ..fled = v.fled;
    scene.topHits.loot.newCrewText = v.newCrew;
    scene.topHits.breaks.text = v.bossBreak;
    scene.topHits.loot.crewName = v.crewName;
  }

  /// 선원 칸 큰 Lv(사용자 'Lv 크게' — S4 카드와 같은 기준): UI가 선원 id → 레벨을 넣는다. 비면 Lv 안 그림.
  set crewLevels(Map<String, int> v) => scene.crewLevels = v;

  /// 선원 이름(필살기 컷인 띠 — 렌더엔 번역이 없어 UI가 선원 id → 지금 언어 이름을 넣는다).
  set crewNames(Map<String, String> v) => scene.topHits.feverStrike.names = v;

  /// 위 HUD 띠(BattleTopStrip) 아래 끝(dp, 전장 상자 위에서) — 보스 카메라가 배·보스를 그 아래에 다 넣는다(S1 '줌인돼 잘림').
  /// UI가 띠 높이를 재서 넣는다(상태 표시줄 포함). 안 넣으면 fx_map topCam.hudTopDp.
  set hudTopDp(double v) => scene.hudTopDp = v;

  /// 카드 앞면 공개 연출을 몇 등급부터 할지(rarities.json id, 피드백 #22 — 기본 fx_map cardFx.minRarity). 운영자·설정이 넣는다.
  set cardFxMinRarity(String rarityId) {
    scene.topHits.loot.revealFrom = scene.tables.rarities.rarities.indexWhere((r) => r.id == rarityId);
  }

  // 그린 카메라 그대로(보스전 당김·확대·피버 가속 포함) — 탭 자리가 그림과 어긋나지 않게.
  Offset worldToDp(Offset world) => painter.top.worldToScreen(world);
  Offset dpToWorld(Offset dp) => painter.top.screenToWorld(dp);

  /// 해역 보스 컷인 (UI가 kind·진행률을 보고 이름을 얹는다). 꺼져 있으면 active false.
  CutInState get cutIn => scene.moments.cutIn;

  /// 운영자: 컷인 다시 보기.
  void resetSeenBosses() => scene.moments.resetSeenBosses();

  /// 운영자 패널용 최근 효과음.
  List<String> get audioLog => scene.audioLog;
}
