import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/quran_provider.dart';

/// Reciter picker — backed by the live, real reciter list (not a
/// hardcoded/guessed one), so it always reflects who actually has audio
/// available.
class ReciterSelectorSheet extends ConsumerWidget {
  const ReciterSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recitersAsync = ref.watch(reciterListProvider);
    final selected = ref.watch(selectedReciterProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundDeep,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختر القارئ',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: recitersAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                  error: (e, st) => Center(
                    child: Text(
                      'تعذّر تحميل قائمة القراء',
                      style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                    ),
                  ),
                  data: (reciters) => ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: reciters.length,
                    itemBuilder: (context, index) {
                      final reciter = reciters[index];
                      final isSelected = selected?.id == reciter.id;
                      return ListTile(
                        onTap: () {
                          ref.read(selectedReciterProvider.notifier).select(reciter);
                          Navigator.of(context).pop();
                        },
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.record_voice_over_rounded,
                          color: isSelected ? AppColors.accent : AppColors.textMuted,
                        ),
                        title: Text(
                          reciter.arabicName,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: isSelected ? AppColors.accent : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
