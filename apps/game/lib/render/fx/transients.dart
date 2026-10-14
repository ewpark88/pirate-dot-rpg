import 'package:game_data/game_data.dart';

/// 풀에서 꺼내 쓰는 일시 객체들. 필드는 꺼낼 때마다 다시 채운다.

/// 배 앞머리에서 목표로 날아가는 발사체. 진행률은 재생기의 표시 위치로 정한다(히트스톱이면 멈춘다).
class Projectile {
  late ProjectileStyle style;
  double fromX = 0;
  double fromY = 0;
  double toX = 0;
  double toY = 0;

  /// 출발·도착 가상 인덱스.
  double startIndex = 0;
  double impactIndex = 0;

  /// 0(출발)~1(도착). 장면이 매 프레임 갱신한다.
  double progress = 0;
  double x = 0;
  double y = 0;
}

/// 이펙트 시트 한 번 재생 (아트 전에는 단색 사각). 궁극기 패턴은 [delayMs]로 시차를, [vx]로 쓸고 지나감을 준다.
class Effect {
  String sheetId = '';
  double x = 0;
  double startX = 0;
  double y = 0;
  double w = 0;
  double h = 0;
  int frames = 1;
  double frameMs = 1;
  double ageMs = 0;
  double delayMs = 0;

  /// px/ms. 0이면 제자리.
  double vx = 0;
  int color = 0;

  bool get visible => ageMs >= delayMs;
  int get frame => ((ageMs - delayMs) / frameMs).floor().clamp(0, frames - 1);
  bool get done => ageMs >= delayMs + frames * frameMs;
}

/// 수중 장판: 표시 위치(가상 인덱스) [endIndex]까지 남는다.
class Zone {
  double x = 0;
  double y = 0;
  double radius = 0;
  double endIndex = 0;
}

/// 처치 때 튀어 올랐다가 배로 빨려가는 코인.
class Coin {
  double fromX = 0;
  double fromY = 0;
  double toX = 0;
  double toY = 0;

  /// 분수처럼 퍼지는 방향(-1~1)과 높이.
  double spread = 0;
  double lift = 0;

  /// 코인 비: 0보다 크면 분수 대신 이만큼 곧장 떨어졌다가 배로 간다.
  double fallPx = 0;
  double ageMs = 0;
  double flyMs = 1;
  double x = 0;
  double y = 0;

  bool get done => ageMs >= flyMs;
}

/// 데미지 숫자 종류.
enum DamageKind { normal, crit, sum }
