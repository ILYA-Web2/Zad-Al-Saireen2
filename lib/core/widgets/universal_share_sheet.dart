import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_colors.dart';
import '../../features/quran/presentation/widgets/quran_ornaments.dart';

/// One reusable "share this" bottom sheet for the whole app — designed
/// once, used everywhere (Quran ayahs, Duas, Hadith, Infallible quotes,
/// Allah's Names, calendar occasions, tasbih stats, etc.) instead of each
/// section growing its own bespoke share button.
///
/// Offers 4 real export paths: a designed image (with a size preset and
/// optional Islamic corner ornament), plain text, a downloadable .txt
/// file, and a proper PDF — the PDF/image plumbing reuses the exact same
/// libraries and pattern already proven working elsewhere in this app
/// (see the Quran Surah export), so nothing new is being risked here.
Future<void> showUniversalShareSheet(
  BuildContext context, {
  required String title,
  required String body,
  String? attribution,
  String sourceLabel = '',
}) {
  return showModalBottomSheet(
    context: context,
    // Pinning to the root navigator is what actually fixes the "sheet
    // gets stuck open forever" bug: without this, the sheet attaches to
    // GoRouter's shell-nested navigator, and tapping a bottom-nav item
    // (which calls context.go() and rebuilds that same navigator's page
    // stack) orphaned the sheet's route entirely — it was left stranded
    // with no page underneath it consistent with its own lifecycle, so
    // neither the drag-to-dismiss, tap-outside, nor back gesture could
    // close it anymore. The root navigator is never touched by the
    // shell's declarative route swaps, so the sheet stays a normal,
    // fully-dismissible route regardless of what the bottom nav does.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => UniversalShareSheet(
      title: title,
      body: body,
      attribution: attribution,
      sourceLabel: sourceLabel,
    ),
  );
}

enum _ShareFormat { square, story, post, auto }

extension on _ShareFormat {
  String get label {
    switch (this) {
      case _ShareFormat.square:
        return 'مربّع';
      case _ShareFormat.story:
        return 'قصّة';
      case _ShareFormat.post:
        return 'منشور';
      case _ShareFormat.auto:
        return 'تلقائي (نص كامل)';
    }
  }

  double? get aspectRatio {
    switch (this) {
      case _ShareFormat.square:
        return 1.0;
      case _ShareFormat.story:
        return 9 / 16;
      case _ShareFormat.post:
        return 4 / 5;
      case _ShareFormat.auto:
        return null;
    }
  }
}

class UniversalShareSheet extends StatefulWidget {
  const UniversalShareSheet({
    super.key,
    required this.title,
    required this.body,
    this.attribution,
    this.sourceLabel = '',
  });

  final String title;
  final String body;
  final String? attribution;
  final String sourceLabel;

  @override
  State<UniversalShareSheet> createState() => _UniversalShareSheetState();
}

class _UniversalShareSheetState extends State<UniversalShareSheet> {
  final GlobalKey _captureKey = GlobalKey();
  _ShareFormat _format = _ShareFormat.square;
  // null = no ornament. Was a plain on/off switch over a single (fairly
  // rough-looking at small sizes) star design — now a real choice among
  // 5 distinct, small-size-legible styles; see quran_ornaments.dart.
  OrnamentStyle? _ornamentStyle = OrnamentStyle.star8;
  bool _isBusy = false;

  String get _displayBody {
    if (_format == _ShareFormat.auto) return widget.body;
    // Fixed-size image formats can't scroll — long text is trimmed to a
    // clean preview length rather than silently overflowing/clipping.
    if (widget.body.length <= 320) return widget.body;
    return '${widget.body.substring(0, 320).trimRight()}…';
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّرت المشاركة، حاول مرة أخرى', textDirection: TextDirection.rtl)),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _shareAsImage() => _run(() async {
        final boundary =
            _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(byteData!.buffer.asUint8List());
        await Share.shareXFiles([XFile(file.path)]);
      });

  Future<void> _shareAsText() => _run(() async {
        final text = [
          widget.title,
          '',
          widget.body,
          if (widget.attribution != null) '\n— ${widget.attribution}',
        ].join('\n');
        await Share.share(text);
      });

  Future<void> _shareAsTextFile() => _run(() async {
        final text = [
          widget.title,
          '',
          widget.body,
          if (widget.attribution != null) '\n— ${widget.attribution}',
          '\nمشارَك عبر تطبيق زاد السائرين',
        ].join('\n');
        final dir = await getTemporaryDirectory();
        final safeName = widget.title.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9]+'), '_');
        final file = File('${dir.path}/$safeName.txt');
        await file.writeAsString(text, encoding: SystemEncoding());
        await Share.shareXFiles([XFile(file.path)]);
      });

  Future<void> _shareAsPdf() => _run(() async {
        final doc = pw.Document();
        final arabicFont = await PdfGoogleFonts.amiriRegular();
        final arabicBold = await PdfGoogleFonts.amiriBold();

        doc.addPage(
          pw.MultiPage(
            textDirection: pw.TextDirection.rtl,
            build: (context) => [
              pw.Center(
                child: pw.Text(
                  widget.title,
                  style: pw.TextStyle(font: arabicBold, fontSize: 24),
                ),
              ),
              if (widget.sourceLabel.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    widget.sourceLabel,
                    style: pw.TextStyle(font: arabicFont, fontSize: 11, color: PdfColors.grey700),
                  ),
                ),
              ],
              pw.SizedBox(height: 20),
              pw.Text(
                widget.body,
                textAlign: pw.TextAlign.justify,
                style: pw.TextStyle(font: arabicFont, fontSize: 16, lineSpacing: 5),
              ),
              if (widget.attribution != null) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  '— ${widget.attribution}',
                  style: pw.TextStyle(font: arabicBold, fontSize: 13),
                ),
              ],
            ],
          ),
        );

        final safeName = widget.title.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z0-9]+'), '_');
        await Printing.sharePdf(bytes: await doc.save(), filename: '$safeName.pdf');
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(
                'مشاركة',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),

              // ── Live preview ──────────────────────────────────────────────
              RepaintBoundary(
                key: _captureKey,
                child: _SharePreviewCard(
                  title: widget.title,
                  body: _displayBody,
                  attribution: widget.attribution,
                  sourceLabel: widget.sourceLabel,
                  aspectRatio: _format.aspectRatio,
                  ornamentStyle: _ornamentStyle,
                ),
              ),
              const SizedBox(height: 16),

              // ── Format presets ────────────────────────────────────────────
              Text('الحجم', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ShareFormat.values.map((f) {
                  final isSelected = f == _format;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _format = f);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent.withOpacity(0.2) : AppColors.glassFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.accent.withOpacity(0.6) : AppColors.glassBorder,
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? AppColors.accent : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // ── Ornament style picker ───────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text('زخرفة إسلامية', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 66,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _OrnamentChoiceTile(
                      label: 'بلا',
                      isSelected: _ornamentStyle == null,
                      onTap: () => setState(() => _ornamentStyle = null),
                      preview: Icon(Icons.block_rounded, size: 20, color: AppColors.textMuted),
                    ),
                    ...OrnamentStyle.values.map((style) => _OrnamentChoiceTile(
                          label: style.arabicLabel,
                          isSelected: _ornamentStyle == style,
                          onTap: () => setState(() => _ornamentStyle = style),
                          preview: IslamicCornerOrnament(size: 26, color: AppColors.accent, style: style),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Actions ───────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _ShareActionButton(icon: Icons.image_rounded, label: 'صورة', busy: _isBusy, onTap: _shareAsImage)),
                  const SizedBox(width: 8),
                  Expanded(child: _ShareActionButton(icon: Icons.text_snippet_rounded, label: 'نص', busy: _isBusy, onTap: _shareAsText)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _ShareActionButton(icon: Icons.description_rounded, label: 'ملف نصي', busy: _isBusy, onTap: _shareAsTextFile)),
                  const SizedBox(width: 8),
                  Expanded(child: _ShareActionButton(icon: Icons.picture_as_pdf_rounded, label: 'PDF', busy: _isBusy, onTap: _shareAsPdf)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  const _ShareActionButton({required this.icon, required this.label, required this.busy, required this.onTap});
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _OrnamentChoiceTile extends StatelessWidget {
  const _OrnamentChoiceTile({required this.label, required this.isSelected, required this.onTap, required this.preview});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.glassFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.glassBorder, width: isSelected ? 1.4 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 26, child: Center(child: preview)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: isSelected ? AppColors.accent : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _SharePreviewCard extends StatelessWidget {
  const _SharePreviewCard({
    required this.title,
    required this.body,
    required this.attribution,
    required this.sourceLabel,
    required this.aspectRatio,
    required this.ornamentStyle,
  });

  final String title;
  final String body;
  final String? attribution;
  final String sourceLabel;
  final double? aspectRatio;
  final OrnamentStyle? ornamentStyle;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryMedium, AppColors.backgroundDeep],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: aspectRatio == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (sourceLabel.isNotEmpty) ...[
            Text(sourceLabel, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.accentLight)),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'Amiri', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          OrnamentalDivider(color: AppColors.accent),
          const SizedBox(height: 14),
          Text(
            body,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'Amiri', fontSize: 16, height: 1.8, color: AppColors.textArabic),
          ),
          if (attribution != null) ...[
            const SizedBox(height: 14),
            Text('— $attribution', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentLight)),
          ],
          // Spacer() only works with a bounded height (the fixed aspect
          // ratio formats) — with `auto` (MainAxisSize.min, unbounded
          // height from the surrounding scroll view), a Spacer here would
          // throw a Flutter layout error at runtime, so a plain fixed gap
          // is used instead in that case.
          if (aspectRatio != null) const Spacer() else const SizedBox(height: 20),
          const SizedBox(height: 10),
          Text('زاد السائرين', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted, letterSpacing: 1)),
        ],
      ),
    );

    final framed = ornamentStyle != null
        ? QuranPageFrame(accentColor: AppColors.accent, style: ornamentStyle!, child: content)
        : content;

    if (aspectRatio == null) return framed;
    return AspectRatio(aspectRatio: aspectRatio!, child: framed);
  }
}
