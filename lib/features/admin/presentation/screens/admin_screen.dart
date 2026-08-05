import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/remote_config_provider.dart';
import '../../../../services/admin_service.dart';
import '../../../../services/youtube_key_rotation_manager.dart';

/// Only reachable after the secret code is typed into the Quran search
/// field — see [HiveService.isAdminUnlocked]. Four tabs matching what was
/// asked for: usage stats, per-section remote kill-switch, broadcast
/// notifications, and forced/optional update control.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'إحصائيات'),
                Tab(text: 'تعطيل قسم'),
                Tab(text: 'إشعار'),
                Tab(text: 'تحديث'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _StatsTab(),
                _SectionsTab(),
                _NotificationTab(),
                _UpdateTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Stats ─────────────────────────────────────────────────────────────
class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  late Future<AdminStats> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminService.instance.getStats();
  }

  void _refresh() => setState(() => _future = AdminService.instance.getStats());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: AppColors.accent));
        }
        final stats = snapshot.data;
        if (stats == null) return const Center(child: Text('تعذّر الجلب'));

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (stats.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stats.error!,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.error),
                  ),
                ),
              Text(
                'ملاحظة: لا يوجد نظام حسابات/تسجيل دخول في التطبيق — "المستخدمون" هنا هو عدد أجهزة مختلفة (device_id) ظهرت في محفوظات البحث، وليس عدد حسابات فعلية.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted, height: 1.6),
              ),
              const SizedBox(height: 14),
              _StatCard(label: 'إجمالي المستخدمين (حسابات مخفية حقيقية)', value: '${stats.totalUsers}'),
              _StatCard(label: 'مستخدمون بحثوا عن شيء على الأقل', value: '${stats.distinctDevices}'),
              _StatCard(label: 'إجمالي عمليات البحث المحفوظة', value: '${stats.totalSearches}'),
              _StatCard(label: 'نتائج بحث مخزّنة مؤقتاً (توفير YouTube API)', value: '${stats.mediaCacheEntries}'),
              _StatCard(label: 'ملفات محمّلة/مخزّنة محلياً (سجلات)', value: '${stats.totalDownloadedFiles}'),
              const SizedBox(height: 20),
              Text(
                'مفاتيح YouTube Data API v3',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              for (final k in stats.apiKeyStatuses)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        k.isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                        size: 18,
                        color: k.isAvailable ? Colors.greenAccent : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          k.maskedKey,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        k.isAvailable ? 'متاح الآن' : 'متوقف حتى ${k.cooldownUntil}',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          try {
                            await AdminService.instance.removeApiKey(k.fullKey);
                            await YoutubeKeyRotationManager.instance.refreshFromRemote();
                            _refresh();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('حُذف المفتاح من قاعدة البيانات لكل المستخدمين')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تعذّر الحذف: $e')),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              _AddApiKeyRow(onChanged: _refresh),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _AddApiKeyRow extends StatefulWidget {
  const _AddApiKeyRow({this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<_AddApiKeyRow> createState() => _AddApiKeyRowState();
}

class _AddApiKeyRowState extends State<_AddApiKeyRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'مفتاح YouTube API جديد',
              hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () async {
            final key = _controller.text.trim();
            if (key.isEmpty) return;
            try {
              await AdminService.instance.addApiKey(key);
              await YoutubeKeyRotationManager.instance.refreshFromRemote();
              _controller.clear();
              widget.onChanged?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('أُضيف المفتاح لقاعدة البيانات — يدخل في التدوير عند كل المستخدمين فوراً')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تعذّر الحفظ: $e')),
                );
              }
            }
          },
          child: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

// ── Tab 2: Disable a section ────────────────────────────────────────────────
class _SectionsTab extends ConsumerStatefulWidget {
  const _SectionsTab();

  @override
  ConsumerState<_SectionsTab> createState() => _SectionsTabState();
}

class _SectionsTabState extends ConsumerState<_SectionsTab> {
  static const _sections = <String, String>{
    'home': 'الرئيسية',
    'quran': 'القرآن الكريم',
    'duas': 'المكتبة الحسينية',
    'tasbih': 'التسبيح',
    'downloads': 'السجل',
    'prayer-times': 'أوقات الصلاة',
    'calendar': 'التقويم الهجري',
    'infallibles': 'المعصومون الأربعة عشر',
    'hadith': 'أحاديث أهل البيت',
    'daily-amaal': 'أعمال اليوم',
    'allah-names': 'أسماء الله الحسنى',
  };

  bool _saving = false;

  Future<void> _toggle(String key, bool disabled) async {
    setState(() => _saving = true);
    final notifier = ref.read(remoteConfigProvider.notifier);
    final current = ref.read(remoteConfigProvider);
    final updated = disabled
        ? [...current.disabledSections, key]
        : current.disabledSections.where((s) => s != key).toList();
    try {
      await AdminService.instance.saveRemoteConfig(current.copyWith(disabledSections: updated));
      await notifier.refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(remoteConfigProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'تعطيل قسم يُظهر له شاشة "قيد التطوير" لكل المستخدمين فوراً، دون تحديث للتطبيق.',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted, height: 1.6),
        ),
        const SizedBox(height: 14),
        for (final entry in _sections.entries)
          SwitchListTile(
            value: config.disabledSections.contains(entry.key),
            onChanged: _saving ? null : (v) => _toggle(entry.key, v),
            activeColor: AppColors.error,
            title: Text(
              entry.value,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, color: AppColors.textPrimary),
            ),
            subtitle: Text(
              config.disabledSections.contains(entry.key) ? 'معطّل حالياً' : 'يعمل بشكل طبيعي',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: config.disabledSections.contains(entry.key) ? AppColors.error : AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Tab 3: Send notification ────────────────────────────────────────────────
class _NotificationTab extends StatefulWidget {
  const _NotificationTab();

  @override
  State<_NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<_NotificationTab> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _image = TextEditingController();
  final _link = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await AdminService.instance.sendNotification(
        title: _title.text.trim(),
        body: _body.text.trim(),
        imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
        linkUrl: _link.text.trim().isEmpty ? null : _link.text.trim(),
      );
      _title.clear();
      _body.clear();
      _image.clear();
      _link.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أُرسل الإشعار لكل المستخدمين')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإرسال: $e')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AdminField(controller: _title, label: 'العنوان *'),
        _AdminField(controller: _body, label: 'النص *', maxLines: 4),
        _AdminField(controller: _image, label: 'رابط صورة (اختياري)'),
        _AdminField(controller: _link, label: 'رابط عند الضغط (اختياري)'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          child: Text(
            _sending ? 'جارٍ الإرسال...' : 'إرسال لكل المستخدمين',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ── Tab 4: Update control ───────────────────────────────────────────────────
class _UpdateTab extends ConsumerStatefulWidget {
  const _UpdateTab();

  @override
  ConsumerState<_UpdateTab> createState() => _UpdateTabState();
}

class _UpdateTabState extends ConsumerState<_UpdateTab> {
  final _url = TextEditingController();
  final _version = TextEditingController();
  bool _force = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(remoteConfigProvider);
    if (!_initialized) {
      _url.text = config.updateUrl;
      _version.text = config.latestVersion;
      _force = config.forceUpdate;
      _initialized = true;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'الإصدار الحالي المُثبَّت في هذا الكود: ${AppConstants.appVersion}',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _AdminField(controller: _version, label: 'أحدث إصدار متاح (مثال: 1.8.0)'),
        _AdminField(controller: _url, label: 'رابط التحديث (متجر التطبيقات)'),
        SwitchListTile(
          value: _force,
          onChanged: (v) => setState(() => _force = v),
          activeColor: AppColors.error,
          title: Text(
            'إيقاف التطبيق بالكامل حتى التحديث',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, color: AppColors.textPrimary),
          ),
          subtitle: Text(
            'عند التفعيل: لا يستطيع أي مستخدم استخدام التطبيق قبل التحديث',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.error),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  try {
                    await AdminService.instance.saveRemoteConfig(config.copyWith(
                      updateUrl: _url.text.trim(),
                      latestVersion: _version.text.trim(),
                      forceUpdate: _force,
                    ));
                    await ref.read(remoteConfigProvider.notifier).refresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم الحفظ ونشره لكل المستخدمين')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
                    }
                  }
                  if (mounted) setState(() => _saving = false);
                },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          child: Text(
            _saving ? 'جارٍ الحفظ...' : 'حفظ ونشر',
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _AdminField extends StatelessWidget {
  const _AdminField({required this.controller, required this.label, this.maxLines = 1});
  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
