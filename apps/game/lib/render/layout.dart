/// 전장 배치 (논리 픽셀, docs/GAME_DESIGN.md 10장 · 기준 battle_ship.gif = 팩 scene3.py). 화면 배치라 코드에 둔다.
library;

/// 논리 해상도 320×180: 전장 0~148 / 선원 슬롯 148~180.
const double kLogicalWidth = 320;
const double kLogicalHeight = 180;
const double kFieldBottom = 148;

/// 내 배 (ship_t1 62×48): 왼쪽 위 (2, 70), 위아래 출렁임은 장면의 shipBob.
const double kShipLeft = 2;
const double kShipTop = 70;
const double kShipWidth = 62;
const double kShipHeight = 48;
const double kShipCenterX = kShipLeft + kShipWidth / 2;
const double kShipCenterY = kShipTop + kShipHeight / 2;

/// 발사체가 떠나는 포구 (엔진 shipX 56 근처, 기준 56~60·100~104).
const double kShipNoseX = 58;
const double kShipNoseY = 100;

/// 포구 화염 중심 (기준 muzzle 32px를 왼쪽 위 (50, 86)에).
const double kMuzzleX = 66;
const double kMuzzleY = 102;

/// 코인이 빨려 드는 곳 (기준 (30, 96)).
const double kCoinTargetX = 30;
const double kCoinTargetY = 96;

/// 적 플레이스홀더 크기 (적 16px 안, 보스 약 48px).
const double kEnemySize = 12;
const double kBossSize = 40;

/// 궁극기 이펙트 중심.
const double kUltimateX = kLogicalWidth / 2;
const double kUltimateY = 96;

/// 선원 슬롯 6칸 윗변 y와 초상 크기 (판 크기·테두리는 fx_map slots).
const double kSlotTop = 149;
const double kSlotSize = 32;
const int kMaxSlots = 8;

/// 화면 1프레임(60fps) 길이 — juice.flashFrames를 시간으로 바꿀 때.
const double kFrameMs = 1000 / 60;

/// 데미지 숫자가 적 머리 위에서 시작하는 높이.
const double kNumberLiftPx = 12;
