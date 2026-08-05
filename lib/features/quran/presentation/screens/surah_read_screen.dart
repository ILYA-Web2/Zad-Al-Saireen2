import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/universal_share_sheet.dart';
import '../../../../main.dart' show quranAudioHandler;
import '../../../../services/hive_service.dart';
import '../../domain/entities/surah_entity.dart';
import '../providers/quran_provider.dart';
import '../widgets/quran_ornaments.dart';

/// A clean, chrome-free reading page: just the Surah's Ayahs, from the
/// Basmalah to the end, rendered large and beautifully in a real Quranic
/// script (Google Fonts "Amiri Quran") — no navigation bars or controls
/// cluttering the page itself. A small settings/export control floats in
/// the corner for font size, PDF export, and image export.
class SurahReadScreen extends ConsumerStatefulWidget {
  const SurahReadScreen({
    super.key,
    required this.surahNumber,
    required this.surahNameArabic,
    required this.revelationTypeArabic,
  });

  final int surahNumber;
  final String surahNameArabic;
  final String revelationTypeArabic;

  @override
  ConsumerState<SurahReadScreen> createState() => _SurahReadScreenState();
}

class _SurahReadScreenState extends ConsumerState<SurahReadScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  Timer? _saveDebounce;
  bool _isExporting = false;
  bool _isNightMode = true;
  bool _hasRestoredScroll = false;

  // Estimated ayah-highlight tracking while this Surah is the one
  // actively playing in the background handler. Deliberately NOT built
  // on exact per-word timestamps — the official timing API for that
  // requires a registered developer's client_id/client_secret and a
  // backend proxy, neither of which this app has. Instead, each Ayah's
  // share of the total audio duration is estimated proportionally to its
  // character count, which tracks a single continuous, steadily-paced
  // recitation reasonably well without needing any new API, credentials,
  // or — most importantly — any change at all to the audio player itself
  // (this only *listens* to the existing position/duration streams the
  // mini player already uses; it can't affect playback even if something
  // here were wrong).
  int? _highlightedAyahNumber;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _isNightMode = HiveService.instance.getSetting<bool>('quran_read_night_mode') ?? true;
    _scrollController.addListener(_onScroll);
    _positionSub = quranAudioHandler.positionStream.listen(_updateAyahHighlight);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _positionSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Saves a single, global "continue reading" bookmark (this Surah +
  // raw scroll offset) — debounced so scrolling doesn't hammer Hive with
  // a write on every frame. This didn't exist before at all: closing the
  // app mid-Surah meant losing your place entirely every single time.
  void _onScroll() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      HiveService.instance.setSetting('quran_last_read_surah', widget.surahNumber);
      HiveService.instance.setSetting('quran_last_read_surah_name', widget.surahNameArabic);
      HiveService.instance.setSetting('quran_last_read_type', widget.revelationTypeArabic);
      HiveService.instance.setSetting('quran_last_read_offset', _scrollController.offset);
    });
  }

  // Restores the saved scroll offset only when this screen is opened for
  // the *same* Surah the bookmark belongs to — opening a different Surah
  // from the list always starts at the top, as expected, and simply
  // overwrites the bookmark once the user scrolls here instead.
  void _restoreScrollPositionIfSaved() {
    final savedSurah = HiveService.instance.getSetting<int>('quran_last_read_surah');
    if (savedSurah != widget.surahNumber) return;
    final savedOffset = HiveService.instance.getSetting<double>('quran_last_read_offset');
    if (savedOffset == null || savedOffset <= 0) return;
    if (!_scrollController.hasClients) return;
    final target = savedOffset.clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  void _updateAyahHighlight(Duration position) {
    // Only meaningful while THIS Surah is the one actually playing in
    // the shared background handler — otherwise clear any stale
    // highlight left over from a previous Surah.
    if (quranAudioHandler.currentSurahNumber != widget.surahNumber) {
      if (_highlightedAyahNumber != null) setState(() => _highlightedAyahNumber = null);
      return;
    }
    final state = ref.read(surahReaderProvider(widget.surahNumber));
    if (state.ayahs.isEmpty) return;
    final totalDuration = quranAudioHandler.duration ?? Duration.zero;
    if (totalDuration.inMilliseconds <= 0) return;

    final totalChars = state.ayahs.fold<int>(0, (sum, a) => sum + a.text.length);
    if (totalChars <= 0) return;

    final elapsedMs = position.inMilliseconds.clamp(0, totalDuration.inMilliseconds);
    final targetChars = totalChars * (elapsedMs / totalDuration.inMilliseconds);

    var cumulative = 0;
    int? matched;
    for (final ayah in state.ayahs) {
      cumulative += ayah.text.length;
      if (targetChars <= cumulative) {
        matched = ayah.numberInSurah;
        break;
      }
    }
    matched ??= state.ayahs.last.numberInSurah;

    if (matched != _highlightedAyahNumber && mounted) {
      setState(() => _highlightedAyahNumber = matched);
    }
  }

  void _toggleNightMode() {
    setState(() => _isNightMode = !_isNightMode);
    HiveService.instance.setSetting('quran_read_night_mode', _isNightMode);
  }

  Color get _pageBackground => _isNightMode ? AppColors.backgroundDeep : const Color(0xFFF5EEDC);
  Color get _textColor => _isNightMode ? AppColors.textPrimary : const Color(0xFF2A1F14);
  Color get _accentColor => _isNightMode ? AppColors.accent : const Color(0xFF8B6914);

  /// Surah 1 (Al-Fatiha) and 9 (At-Tawbah) never get a separately-shown
  /// Basmalah header — Al-Fatiha's first Ayah already IS the Basmalah, and
  /// At-Tawbah traditionally omits it.
  bool get _showsBasmalahHeader => widget.surahNumber != 1 && widget.surahNumber != 9;

  Future<void> _exportAsImage() async {
    setState(() => _isExporting = true);
    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'سورة_${widget.surahNameArabic}.png', mimeType: 'image/png')],
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تصدير الصورة')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAsPdf(List<AyahEntity> ayahs) async {
    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();
      final arabicFont = await PdfGoogleFonts.amiriRegular();
      final arabicBold = await PdfGoogleFonts.amiriBold();

      doc.addPage(
        pw.MultiPage(
          textDirection: pw.TextDirection.rtl,
          build: (context) => [
            pw.Center(
              child: pw.Text(
                'سورة ${stripArabicDiacritics(widget.surahNameArabic)}',
                style: pw.TextStyle(font: arabicBold, fontSize: 26),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                widget.revelationTypeArabic,
                style: pw.TextStyle(font: arabicFont, fontSize: 12, color: PdfColors.grey700),
              ),
            ),
            pw.SizedBox(height: 20),
            if (_showsBasmalahHeader)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    style: pw.TextStyle(font: arabicBold, fontSize: 20),
                  ),
                ),
              ),
            pw.Text(
              ayahs.map((a) => '${a.text} (${a.numberInSurah})').join('  '),
              textAlign: pw.TextAlign.justify,
              style: pw.TextStyle(font: arabicFont, fontSize: 18, lineSpacing: 6),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'سورة_${widget.surahNameArabic}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تصدير الملف')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(surahReaderProvider(widget.surahNumber));

    if (!_hasRestoredScroll && !state.isLoading && state.error == null && state.ayahs.isNotEmpty) {
      _hasRestoredScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreScrollPositionIfSaved();
      });
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            if (state.isLoading)
              Center(child: CircularProgressIndicator(color: AppColors.accent))
            else if (state.error != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.error),
                    const SizedBox(height: 10),
                    Text('تعذّر تحميل السورة',
                        style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () =>
                          ref.read(surahReaderProvider(widget.surahNumber).notifier).loadAyahs(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            else
              QuranPageFrame(
                accentColor: _accentColor,
                child: RepaintBoundary(
                  key: _captureKey,
                  child: Container(
                    color: _pageBackground,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 70, 24, 100),
                      child: Column(
                        children: [
                          Text(
                            'سورة ${stripArabicDiacritics(widget.surahNameArabic)}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.amiri(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.revelationTypeArabic,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _accentColor.withOpacity(0.8)),
                          ),
                          const SizedBox(height: 14),
                          OrnamentalDivider(color: _accentColor),
                          const SizedBox(height: 14),
                          if (_showsBasmalahHeader)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Text(
                                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                                style: GoogleFonts.amiriQuran(
                                  fontSize: state.fontSize + 4,
                                  color: _accentColor,
                                ),
                              ),
                            ),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: RichText(
                              textAlign: TextAlign.justify,
                              text: TextSpan(
                                children: state.ayahs.map((ayah) {
                                  final isHighlighted = ayah.numberInSurah == _highlightedAyahNumber;
                                  return TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${ayah.text} ',
                                        style: GoogleFonts.amiriQuran(
                                          fontSize: state.fontSize,
                                          height: state.lineHeight,
                                          color: _textColor,
                                          backgroundColor: isHighlighted
                                              ? _accentColor.withOpacity(0.22)
                                              : null,
                                        ),
                                      ),
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: GestureDetector(
                                            onLongPress: () {
                                              HapticFeedback.mediumImpact();
                                              showUniversalShareSheet(
                                                context,
                                                title: 'سورة ${stripArabicDiacritics(widget.surahNameArabic)}',
                                                body: ayah.text,
                                                sourceLabel: 'الآية ${ayah.numberInSurah}',
                                              );
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: _accentColor.withOpacity(0.5)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${ayah.numberInSurah}',
                                                style: TextStyle(fontSize: 12, color: _accentColor),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: ' '),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Minimal floating controls (back + font size + export) ──────────
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _RoundButton(icon: Icons.arrow_forward_rounded, onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  if (_isExporting)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    )
                  else ...[
                    _RoundButton(
                      icon: Icons.text_decrease_rounded,
                      onTap: () => ref
                          .read(surahReaderProvider(widget.surahNumber).notifier)
                          .setFontSize((state.fontSize - 2).clamp(16, 40)),
                    ),
                    const SizedBox(width: 6),
                    _RoundButton(
                      icon: Icons.text_increase_rounded,
                      onTap: () => ref
                          .read(surahReaderProvider(widget.surahNumber).notifier)
                          .setFontSize((state.fontSize + 2).clamp(16, 40)),
                    ),
                    const SizedBox(width: 6),
                    _RoundButton(icon: Icons.image_rounded, onTap: _exportAsImage),
                    const SizedBox(width: 6),
                    _RoundButton(
                      icon: Icons.picture_as_pdf_rounded,
                      onTap: () => _exportAsPdf(state.ayahs),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.glassFill,
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Icon(icon, size: 17, color: AppColors.textSecondary),
      ),
    );
  }
}
