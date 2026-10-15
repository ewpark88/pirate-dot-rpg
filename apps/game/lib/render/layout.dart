/// 전장 배치 (논리 픽셀, docs/GAME_DESIGN.md 10장 · 기준 battle_ship.gif = 팩 scene3.py). 화면 배치라 코드에 둔다.
library;

import 'dart:ui' show Size;

export 'package:pirate_dot/render/viewport/battle_frame.dart' show BattleFrame, battleFrameFor;

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

/// 배를 키울 때 기준이 되는 높이 (뱃머리 포구 근처) — 이 줄과 오른쪽 끝은 크기가 바뀌어도 그대로.
const double kShipPivotY = 102;

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

/// 보스를 보이는 오른쪽 끝 안에 그릴 때 끝에서 띄우는 거리 (보스 그림 폭 64의 절반 + 2).
const double kBossEdgeInset = 34;

/// 궁극기 이펙트 중심.
const double kUltimateX = kLogicalWidth / 2;
const double kUltimateY = 96;

/// 선원 줄 (화면 배치 v2): 슬롯 6칸 + 오른쪽 끝 궁극기·보스 도전 버튼. 위치는 BattleFrame이 계산한다.
/// 슬롯 판 36×31(등급 테두리 2도트 — 색은 fx_map slots), 초상 32px.
const double kSlotSize = 32;
const int kMaxSlots = 8;
const int kSlotCount = 6;
const Size kSlotPlateSize = Size(36, 31);
const double kSlotLeft = 6;
const double kSlotStep = 40;

/// 선원 줄 높이: 최소 32도트(기준 화면)이면서 56dp 이상(버튼이 들어가게).
const double kSlotBandMinDots = 32;
const double kSlotBandMinDp = 56;

/// 선원 줄 도트 1칸의 최대 dp — 태블릿에서 슬롯(36칸)이 72dp를 넘지 않게(S1: 72~80dp 상한).
const double kBandDotMaxDp = 2;

/// 큰 칸 배치(기기): 칸 최대 변·가장자리·칸 사이·위아래 여백 (dp). 6칸 + 궁극기가 한 줄에 들어가는 가장 큰 정사각.
const double kSlotMaxDp = 72;
const double kSlotEdgeDp = 6;
const double kSlotGapDp = 4;
const double kSlotPadDp = 8;

/// 버튼 칸 사이·가장자리 여백, 가장 작은 버튼 (도트).
const double kButtonGap = 3;
const double kButtonMinDots = 16;

/// 늘어난 높이 중 하늘(위)로 가는 몫 — 나머지는 깊은 바다(필드 아래).
const double kSkyShare = 0.7;

/// 화면 1프레임(60fps) 길이 — juice.flashFrames를 시간으로 바꿀 때.
const double kFrameMs = 1000 / 60;

/// 데미지 숫자가 적 머리 위에서 시작하는 높이.
const double kNumberLiftPx = 12;
