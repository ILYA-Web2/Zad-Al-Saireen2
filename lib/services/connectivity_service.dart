import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;

/// Robust, non-blocking connectivity checker.
///
/// The old approach (a single strict synchronous check) is what caused the
/// "تعذر الاتصال" false-positive even on a perfectly working connection: any
/// slow DNS lookup or brief hiccup was treated as "offline" with no retry.
///
/// This service instead:
///  • treats [ConnectivityResult] as a *hint* only (a device can report
///    "wifi" while the router itself has no internet, and vice versa a
///    metered/VPN interface can still work) — so
///  • it always confirms with a fast, real network probe (DNS lookup) with
///    a short timeout,
///  • debounces rapid connectivity flapping so the UI doesn't flicker,
///  • and never throws — every failure path resolves to a clean boolean.
class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _statusController;

  Timer? _debounce;
  Timer? _pollTimer;
  bool _lastKnownOnline = true;
  bool _started = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Broadcast stream of `true` (online) / `false` (offline). Safe to
  /// listen to from multiple widgets (e.g. a global banner). Lazily
  /// (re)created so listening still works even after a previous
  /// dispose() closed the old controller.
  Stream<bool> get onStatusChange =>
      (_statusController ??= StreamController<bool>.broadcast()).stream;

  bool get lastKnownOnline => _lastKnownOnline;

  /// Safe to call multiple times (e.g. once per screen instance) — a
  /// second call after a prior dispose() now correctly re-subscribes
  /// instead of silently doing nothing, which is what happened before
  /// because `_sub`/`_pollTimer` were left non-null (but cancelled)
  /// after dispose(), so the `??=` guards here never re-armed anything.
  void start() {
    if (_started) return;
    _started = true;
    _statusController ??= StreamController<bool>.broadcast();
    WidgetsBinding.instance.addObserver(this);

    _sub = _connectivity.onConnectivityChanged.listen((_) {
      _debounce?.cancel();
      // Debounce: a flurry of interface-switch events (wifi → mobile data
      // during a handover) settles within ~600ms; checking immediately on
      // every event is exactly what produced spurious "offline" flashes.
      _debounce = Timer(const Duration(milliseconds: 600), _checkNow);
    });
    _startPolling();
    _checkNow();
  }

  void _startPolling() {
    // The OS-level connectivity stream above only fires when the network
    // *interface* itself changes (e.g. wifi radio turns off) — it never
    // fires just because the wifi you're already connected to regained
    // real internet access after being stuck behind a dead router/DNS.
    // That's exactly what left the offline banner stuck forever even
    // after the connection came back: nothing was ever re-checking.
    // Polling every 30s catches that case too, at low cost — paused
    // entirely while the app is backgrounded (see didChangeAppLifecycleState).
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _checkNow();
    } else if (state == AppLifecycleState.paused) {
      // No one can see the offline banner while backgrounded — no point
      // burning battery on a real network probe every 30s until we're
      // foregrounded again.
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _sub = null;
    _debounce?.cancel();
    _debounce = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _statusController?.close();
    _statusController = null;
    _started = false;
  }

  Future<void> _checkNow() async {
    final online = await hasRealInternetAccess();
    if (online != _lastKnownOnline) {
      _lastKnownOnline = online;
      final controller = _statusController;
      if (controller != null && !controller.isClosed) controller.add(online);
    }
  }

  /// Performs a fast, real reachability probe rather than trusting the OS
  /// radio state alone. Any exception (timeout, DNS failure, socket error)
  /// is caught and cleanly reported as "offline" — never crashes the caller.
  Future<bool> hasRealInternetAccess() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        return false;
      }
      // dart:io has no raw DNS/socket access on web (browsers don't expose
      // it) — connectivity_plus's own web implementation already reflects
      // the browser's `navigator.onLine` signal, which is the most this
      // platform can tell us. Trusting it here (rather than falling
      // through to a lookup that would always throw) is what was missing;
      // without this, the app previously reported "offline" permanently
      // on web even on a perfectly working connection.
      if (kIsWeb) return true;
    } catch (_) {
      // If the platform channel itself misbehaves, fall through to the
      // direct probe below instead of giving up immediately.
    }

    try {
      final lookup = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
