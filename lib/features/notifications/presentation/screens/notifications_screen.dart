import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/admin_service.dart';

/// Lists every broadcast notification the admin panel has sent (not just
/// unseen ones) — this is the persistent record the person can revisit,
/// separate from the once-only full-screen popup shown by
/// [AdminNotificationOverlay].
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AdminNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.instance.getActiveNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<AdminNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'لا توجد إشعارات حتى الآن',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = items[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  border: Border.all(color: AppColors.glassBorder, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((n.imageUrl ?? '').isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: CachedNetworkImage(
                            imageUrl: n.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(color: AppColors.primaryMedium),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.body,
                              textDirection: TextDirection.rtl,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.5,
                              ),
                            ),
                            if ((n.linkUrl ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.tryParse(n.linkUrl!);
                                    if (uri != null && await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Text(
                                    'فتح الرابط',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
