import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Compares dotted version strings numerically (so "1.10.0" correctly
/// counts as newer than "1.9.0", unlike a plain string comparison).
bool isVersionOlderThan(String current, String latest) {
  if (latest.isEmpty) return false;
  final a = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final b = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < b.length; i++) {
    final av = i < a.length ? a[i] : 0;
    final bv = b[i];
    if (av != bv) return av < bv;
  }
  return false;
}

/// Absolutely blocking — no dismiss, no tap-outside, no back button — this
/// is only ever shown when the admin panel has explicitly marked an
/// update as mandatory ("إيقاف التطبيق بالكامل حتى التحديث").
class ForceUpdateGate extends StatelessWidget {
  const ForceUpdateGate({super.key, required this.updateUrl, required this.message});
  final String updateUrl;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update_rounded, size: 56, color: AppColors.accent),
                  const SizedBox(height: 20),
                  Text(
                    'يتوفر تحديث مهم',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message.isNotEmpty
                        ? message
                        : 'يجب تحديث التطبيق للمتابعة — لن يعمل التطبيق قبل التحديث.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.tryParse(updateUrl);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'تحديث الآن',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
