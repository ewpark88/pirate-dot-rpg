import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 풀에서 꺼내 쓰는 일시 객체들. 필드는 꺼낼 때마다 다시 채운다.

/// 배 앞머리에서 목표로 날아가는 발사체. 진행률은 재생기의 표시 위치로 정한다(히트스톱이면 멈춘다).
class Projectile {
  late ProjectileStyle style;

  /// 발사한 계열 (스프라이트 키 `projectile:<family>`).
  String family = '';

  /// 쏜 선원 (PB 무기 그림 `weapon:<crewId>`, 없으면 계열 그림).
  String crewId = '';
  double fromX = 0;
  double fromY = 0;
  double toX = 0;
  double toY = 0;

  /// 탑다운(T2): 화면에서는 곧게 날고, 포물선·물수제비 높이는 크기·그림자로 보인다(heightAt).
  bool flat = false;

  /// 출발·도착 가상 인덱스.
  double startIndex = 0;
  double impactIndex = 0;

  /// 옆으로 휘는 정도(단위, 추적 깃털 — 길 가운데에서 가장 크게). 0이면 곧게.
  double curve = 0;

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

  /// 이 코인이 나르는 골드 (도착하면 UI '+금액'). 상한에 걸린 처치는 마지막 코인에 더한다.
  BigNum amount = BigNum.zero;

  /// 코인 비: 0보다 크면 분수 대신 이만큼 곧장 떨어졌다가 배로 간다.
  double fallPx = 0;
  double ageMs = 0;
  double flyMs = 1;
  double x = 0;
  double y = 0;

  bool get done => ageMs >= flyMs;
}

/// 데미지 숫자 종류.
/// [ship] = 내 배가 받은 피해(빨강, 사용자 지적 '내 체력은?').
enum DamageKind { normal, crit, sum, ship }
