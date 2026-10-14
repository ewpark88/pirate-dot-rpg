/// 크기가 고정된 객체 풀. 처음에 [capacity]개를 모두 만들고, 다 쓰면 가장 오래된 것을 회수해 다시 쓴다.
///
/// 덕분에 이펙트가 아무리 몰려도 동시 개수는 [capacity]를 넘지 않고, 프레임 중에 새 객체를 만들지 않는다.
class Pool<T> {
  Pool(this.capacity, T Function() create) : _free = List<T>.generate(capacity, (_) => create());

  final int capacity;
  final List<T> _free;
  final List<T> _active = List<T>.empty(growable: true);

  /// 쓰는 중인 객체, 오래된 것이 앞.
  List<T> get active => _active;

  /// 지금까지 만든 객체 수 (항상 [capacity]).
  int get created => capacity;

  /// 빈 객체를 꺼낸다. 없으면 가장 오래된 것을 회수한다. 받은 쪽이 모든 필드를 다시 채운다.
  T obtain() {
    final item = _free.isNotEmpty ? _free.removeLast() : _active.removeAt(0);
    _active.add(item);
    return item;
  }

  void release(T item) {
    if (_active.remove(item)) _free.add(item);
  }

  /// [done]이 true인 객체를 모두 돌려놓는다 (순서 유지, 새 리스트 없음).
  void releaseWhere(bool Function(T item) done) {
    var w = 0;
    for (var r = 0; r < _active.length; r++) {
      final item = _active[r];
      if (done(item)) {
        _free.add(item);
      } else {
        _active[w++] = item;
      }
    }
    _active.length = w;
  }

  void clear() {
    _free.addAll(_active);
    _active.length = 0;
  }
}
