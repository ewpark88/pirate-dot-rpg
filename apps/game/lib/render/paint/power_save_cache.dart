import 'dart:ui';

/// 절전 모드: 장면이 갱신된 프레임에만 그림을 새로 기록하고, 나머지 프레임은 직전 그림을 다시 그린다.
class PowerSaveCache {
  Picture? _last;

  /// 새로 기록한 횟수 / 다시 쓴 횟수 (테스트·운영자 확인용).
  int recorded = 0;
  int reused = 0;

  void render(Canvas canvas, {required bool dirty, required void Function(Canvas canvas) paint}) {
    final last = _last;
    if (!dirty && last != null) {
      reused++;
      canvas.drawPicture(last);
      return;
    }
    final recorder = PictureRecorder();
    paint(Canvas(recorder));
    final picture = recorder.endRecording();
    last?.dispose();
    _last = picture;
    recorded++;
    canvas.drawPicture(picture);
  }

  /// 절전을 끄거나 장면이 바뀌면 버린다.
  void dispose() {
    _last?.dispose();
    _last = null;
  }
}
