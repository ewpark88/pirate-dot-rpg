/// 전장 배치 (논리 픽셀, docs/GAME_DESIGN.md 10장). 밸런스 수치가 아니라 화면 배치라 코드에 둔다.
library;

/// 논리 해상도 320×180: 전장 0~148 / 선원 슬롯 148~180.
const double kLogicalWidth = 320;
const double kLogicalHeight = 180;
const double kFieldBottom = 148;

/// 수평선(하늘/바다 경계)과 물속 시작.
const double kHorizonY = 64;
const double kWaterlineY = 108;

/// 내 배 (플레이스홀더 약 56×46). 앞머리 x=56 (S1 공지).
const double kShipLeft = 0;
const double kShipTop = 62;
const double kShipWidth = 56;
const double kShipHeight = 46;
const double kShipNoseX = kShipLeft + kShipWidth;
const double kShipNoseY = kShipTop + kShipHeight / 2;
const double kShipCenterX = kShipLeft + kShipWidth / 2;
const double kShipCenterY = kShipNoseY;

/// 적 플레이스홀더 크기 (적 16px 안, 보스 약 48px).
const double kEnemySize = 12;
const double kBossSize = 40;

/// 궁극기 이펙트 중심.
const double kUltimateX = kLogicalWidth / 2;
const double kUltimateY = 96;

/// 선원 슬롯 줄.
const double kSlotTop = kFieldBottom + 2;
const double kSlotSize = 28;
const double kSlotGap = 4;
const int kMaxSlots = 8;

/// 화면 1프레임(60fps) 길이 — juice.flashFrames를 시간으로 바꿀 때.
const double kFrameMs = 1000 / 60;

/// 데미지 숫자가 적 머리 위에서 시작하는 높이.
const double kNumberLiftPx = 8;
