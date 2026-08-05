import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/admin_service.dart';
import '../../services/hive_service.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';

/// Fetches active broadcast notifications once, shortly after the shell
/// is on screen (never blocking startup), and shows whichever ones this
/// installation hasn't dismissed yet — one at a time, full-screen, with
/// only an X or a tap outside to close, exactly like a mobile game's
/// event popup. Once closed, [HiveService.markNotificationDismissed]
/// means it never appears again for this person.
class AdminNotificationOverlay extends StatefulWidget {
  const AdminNotificationOverlay({super.key});

  @override
  State<AdminNotificationOverlay> createState() => _AdminNotificationOverlayState();
}

class _AdminNotificationOverlayState extends State<AdminNotificationOverlay> {
  List<AdminNotification> _queue = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await AdminService.instance.getActiveNotifications();
    final dismissed = HiveService.instance.getDismissedNotificationIds();
    final pending = all.where((n) => !dismissed.contains(n.id)).toList();
    if (mounted) setState(() {
      _queue = pending;
      _loaded = true;
    });
  }

  Future<void> _dismiss(AdminNotification n) async {
    await HiveService.instance.markNotificationDismissed(n.id);
    if (mounted) setState(() => _queue = _queue.where((q) => q.id != n.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _queue.isEmpty) return const SizedBox.shrink();
    final notification = _queue.first;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _dismiss(notification),
        child: Container(
          color: Colors.black.withOpacity(0.72),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps so the card itself doesn't dismiss
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 380,
                  minWidth: MediaQuery.sizeOf(context).width * 0.82,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDeep,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius + 2),
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          // Without this, a notification with no image left
                          // the Stack with zero non-positioned children —
                          // it would collapse to no size at all, and the
                          // close button (positioned relative to it) could
                          // fail to render in a sane spot.
                          if ((notification.imageUrl ?? '').isEmpty)
                            const SizedBox(width: double.infinity, height: 48),
                          if ((notification.imageUrl ?? '').isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: CachedNetworkImage(
                                  imageUrl: notification.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _dismiss(notification),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              notification.title,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              notification.body,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                            ),
                            if ((notification.linkUrl ?? '').isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  final uri = Uri.tryParse(notification.linkUrl!);
                                  if (uri != null && await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'فتح الرابط',
                                  style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
