import 'dart:async';

/// "The money changed." The data layer announces it after a transfer, and any
/// screen showing balances or history (Home now, Activity later) refreshes
/// itself, so no screen has to know about the others.
class WalletEvents {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notifyChanged() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
