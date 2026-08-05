import 'package:flutter/material.dart';

enum DuaContentType { text, pdf }

/// A single library item — the actual file (PDF or plain text) lives in
/// the project's GitHub repo, not bundled in the app; [repoPath] is
/// resolved to a real download URL by CloudFileService and cached locally
/// after the first open.
class DuaModel {
  const DuaModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.contentType,
    required this.repoPath,
    this.audioRepoPath,
    this.audioLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final DuaContentType contentType;

  /// Path relative to the repo root, e.g.
  /// "cloud_content/duas/pdf/sahifa_sajjadiyya.pdf".
  final String repoPath;

  /// Present only for items with an accompanying recitation (e.g. Dua
  /// Kumayl) — same cloud-download-once-then-offline treatment as the
  /// text/PDF itself.
  final String? audioRepoPath;
  final String? audioLabel;

  bool get hasAudio => audioRepoPath != null;
}
