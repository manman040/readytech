import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device currently has a usable route to the network.
enum NetworkStatus { online, offline }

/// Reports connectivity changes to the rest of the app.
///
/// This answers "does the device have an interface up", which is a useful
/// signal for showing an offline banner and for deciding whether to retry. It
/// is deliberately not treated as proof that Supabase is reachable - the app
/// still confirms critical state (payment, job completion) with the backend
/// rather than inferring it from connectivity.
abstract interface class ConnectivityService {
  /// Current status, as last observed.
  NetworkStatus get status;

  /// Emits on every change. Does not re-emit the same status twice.
  Stream<NetworkStatus> get onStatusChanged;

  Future<void> dispose();
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(_handleChange);
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<NetworkStatus>.broadcast();

  NetworkStatus _status = NetworkStatus.online;

  @override
  NetworkStatus get status => _status;

  @override
  Stream<NetworkStatus> get onStatusChanged => _controller.stream;

  /// Reads the initial value. Called once during bootstrap so the first frame
  /// already knows whether the device is offline.
  Future<void> initialise() async {
    _handleChange(await _connectivity.checkConnectivity());
  }

  void _handleChange(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none)
        ? NetworkStatus.online
        : NetworkStatus.offline;

    if (next == _status) return;
    _status = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }
}
