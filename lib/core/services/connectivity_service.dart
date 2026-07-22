import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around connectivity_plus so the rest of the app depends on
/// one small interface instead of the plugin directly.
///
/// A positive connectivity result (wifi/mobile/ethernet) does NOT guarantee
/// internet actually works (captive portals, router with no WAN) — it's used
/// only to short-circuit the *known-offline* case so a bed fetch doesn't sit
/// through a ~10s TCP timeout when the radio is plainly off. The real fetch
/// still runs, and its own timeout is the ultimate safety net.
class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  final _connectivity = Connectivity();

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Emits true/false whenever device connectivity changes.
  Stream<bool> get onlineStream => _connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
}
