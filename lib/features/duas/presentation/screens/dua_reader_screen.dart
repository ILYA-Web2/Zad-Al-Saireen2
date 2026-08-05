import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/universal_share_sheet.dart';
import '../../../../services/cloud_file_service.dart';
import '../../../../services/audio_cache_service.dart';
import '../../../../services/quick_audio_player_service.dart';
import '../../data/models/dua_model.dart';
import '../providers/duas_provider.dart';

/// Opens any library item — PDFs render with `printing`'s built-in viewer
/// (no extra native plugin needed), and Dua Kumayl gets a dedicated
/// text+listen experience. Everything downloads once via
/// [CloudFileService] and is cached locally forever after.
class DuaReaderScreen extends ConsumerWidget {
  const DuaReaderScreen({super.key, required this.duaId});
  final String duaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dua = ref.watch(duaByIdProvider(duaId));

    if (dua == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDeep,
        body: Center(
          child: Text('غير موجود', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
        ),
      );
    }

    return dua.contentType == DuaContentType.pdf
        ? _PdfReaderView(dua: dua)
        : _TextReaderView(dua: dua);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PDF items — Sahifa Sajjadiyya, Sahifa Alawiyya, Ziyarat Ashura
// ─────────────────────────────────────────────────────────────────────────
class _PdfReaderView extends StatefulWidget {
  const _PdfReaderView({required this.dua});
  final DuaModel dua;

  @override
  State<_PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<_PdfReaderView> {
  double _progress = 0.0;
  bool _isDownloading = true;
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isDownloading = true;
      _error = null;
    });
    try {
      final bytes = await CloudFileService.instance.downloadBytes(
        widget.dua.repoPath,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل الملف — تحقق من الاتصال';
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        title: Text(widget.dua.title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.error),
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                  ],
                ),
              )
            : _isDownloading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: _progress > 0 ? _progress : null,
                            color: AppColors.accent,
                            strokeWidth: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _progress > 0
                              ? 'تحميل لمرة واحدة… ${(_progress * 100).toStringAsFixed(0)}٪'
                              : 'جارٍ التحميل…',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'سيعمل بدون إنترنت بعد هذه المرة',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : PdfPreview(
                    build: (format) => _bytes!,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: true,
                    scrollViewDecoration: BoxDecoration(color: AppColors.backgroundDeep),
                    pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white),
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Dua Kumayl — dedicated text + listen experience
// ─────────────────────────────────────────────────────────────────────────
class _TextReaderView extends StatefulWidget {
  const _TextReaderView({required this.dua});
  final DuaModel dua;

  @override
  State<_TextReaderView> createState() => _TextReaderViewState();
}

class _TextReaderViewState extends State<_TextReaderView> {
  String? _text;
  String? _error;
  bool _isPlaying = false;
  double _fontSize = 20;

  // Offline-download state for the audio — didn't exist before at all:
  // audio only ever got cached silently *after* being played once, so
  // there was no way to prepare it for offline use (e.g. before a trip)
  // without first sitting through a full listen while still online.
  bool _isAudioCached = false;
  bool _isDownloadingAudio = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
    _checkAudioCacheStatus();
  }

  Future<void> _checkAudioCacheStatus() async {
    final audioPath = widget.dua.audioRepoPath;
    if (audioPath == null) return;
    final url = CloudFileService.instance.buildUrl(audioPath);
    final cached = await AudioCacheService.instance.isCached(url);
    if (mounted) setState(() => _isAudioCached = cached);
  }

  Future<void> _downloadAudioForOffline() async {
    final audioPath = widget.dua.audioRepoPath;
    if (audioPath == null || _isDownloadingAudio || _isAudioCached) return;
    final url = CloudFileService.instance.buildUrl(audioPath);
    setState(() {
      _isDownloadingAudio = true;
      _downloadProgress = 0.0;
    });
    try {
      await AudioCacheService.instance.downloadForOffline(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) setState(() => _isAudioCached = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تحميل الصوت — تحقق من الاتصال', textDirection: TextDirection.rtl)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingAudio = false);
    }
  }

  Future<void> _load() async {
    try {
      final text = await CloudFileService.instance.downloadText(widget.dua.repoPath);
      if (mounted) setState(() => _text = text);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل النص — تحقق من الاتصال');
    }
  }

  Future<void> _toggleListen() async {
    final audioPath = widget.dua.audioRepoPath;
    if (audioPath == null) return;
    final url = CloudFileService.instance.buildUrl(audioPath);
    try {
      await QuickAudioPlayerService.instance.playOrToggle(url);
      if (mounted) {
        setState(() => _isPlaying = QuickAudioPlayerService.instance.player.playing);
      }
    } catch (_) {
      // A dead/expired audio link must show "not playing" instead of
      // throwing an unhandled exception straight out of a tap handler.
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.dua.title,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.text_decrease_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(14, 34)),
                  ),
                  IconButton(
                    icon: Icon(Icons.text_increase_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(14, 34)),
                  ),
                  // Didn't exist before — a proper share sheet for the
                  // full text (image/text/txt file/PDF), not just the
                  // dedicated per-line copy already available further down.
                  IconButton(
                    icon: Icon(Icons.share_rounded, size: 18, color: AppColors.textMuted),
                    onPressed: _text == null
                        ? null
                        : () => showUniversalShareSheet(
                              context,
                              title: widget.dua.title,
                              body: _text!,
                            ),
                  ),
                ],
              ),
            ),
            if (widget.dua.hasAudio)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _toggleListen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(_isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                            color: AppColors.accent, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('استماع',
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                              if (widget.dua.audioLabel != null)
                                Text(widget.dua.audioLabel!,
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _isAudioCached ? null : _downloadAudioForOffline,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _isDownloadingAudio
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      value: _downloadProgress > 0 ? _downloadProgress : null,
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : Icon(
                                    _isAudioCached ? Icons.download_done_rounded : Icons.download_rounded,
                                    size: 20,
                                    color: _isAudioCached ? AppColors.accentLight : AppColors.textMuted,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.error),
                          const SizedBox(height: 10),
                          Text(_error!, style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                        ],
                      ),
                    )
                  : _text == null
                      ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              _text!,
                              textAlign: TextAlign.justify,
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: _fontSize,
                                height: 1.9,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
