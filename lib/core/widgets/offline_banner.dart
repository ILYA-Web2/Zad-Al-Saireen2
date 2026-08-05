import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';
import '../theme/app_colors.dart';

/// A thin, non-blocking banner that appears only while the device is
/// genuinely offline (confirmed by [ConnectivityService], not just an OS
/// radio flag) and disappears automatically the moment connectivity is
/// restored. It never intercepts taps and never blocks the UI underneath.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _offline = false;
  late final Stream<bool> _stream;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.start();
    _offline = !ConnectivityService.instance.lastKnownOnline;
    _stream = ConnectivityService.instance.onStatusChange;
    _stream.listen((online) {
      if (mounted) setState(() => _offline = !online);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axisAlignment: -1,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: _offline
          ? IgnorePointer(
              key: const ValueKey('offline'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 14, color: AppColors.error),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'لا يوجد اتصال بالإنترنت حالياً',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.error,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('online')),
    );
  }
}
