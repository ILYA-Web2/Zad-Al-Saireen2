import 'package:flutter/material.dart';
import '../models/dua_model.dart';

/// The full content catalog — every entry's actual file lives in the
/// project's GitHub repo (not bundled in the app itself) and is fetched
/// once via CloudFileService, then cached locally forever after. Old
/// hardcoded/truncated dua text has been removed entirely in favor of
/// this — every item here is a real, complete, sourced file.
class DuasLocalDataSource {
  static const List<DuaModel> allDuas = [
    DuaModel(
      id: 'kumayl',
      title: 'دعاء كميل',
      subtitle: 'علّمه الإمام علي عليه السلام لكميل بن زياد',
      icon: Icons.auto_stories_rounded,
      contentType: DuaContentType.text,
      repoPath: 'cloud_content/duas/text/kumayl.txt',
      audioRepoPath: 'cloud_content/duas/audio/kumayl_halawaji.mp3',
      audioLabel: 'بصوت الرادود أباذر الحلواجي',
    ),
    DuaModel(
      id: 'ziyarat_ashura',
      title: 'زيارة عاشوراء',
      subtitle: 'زيارة الإمام الحسين عليه السلام',
      icon: Icons.mosque_rounded,
      contentType: DuaContentType.pdf,
      repoPath: 'cloud_content/duas/pdf/ziyarat_ashura.pdf',
    ),
    DuaModel(
      id: 'sahifa_sajjadiyya',
      title: 'الصحيفة السجادية الكاملة',
      subtitle: 'الإمام علي بن الحسين زين العابدين عليه السلام',
      icon: Icons.menu_book_rounded,
      contentType: DuaContentType.pdf,
      repoPath: 'cloud_content/duas/pdf/sahifa_sajjadiyya.pdf',
    ),
    DuaModel(
      id: 'sahifa_alawiyya',
      title: 'الصحيفة العلوية الجامعة',
      subtitle: 'جمع السيد محمد باقر موحد الأبطحي',
      icon: Icons.menu_book_rounded,
      contentType: DuaContentType.pdf,
      repoPath: 'cloud_content/duas/pdf/sahifa_alawiyya.pdf',
    ),
  ];

  static DuaModel? getById(String id) {
    for (final dua in allDuas) {
      if (dua.id == id) return dua;
    }
    return null;
  }
}
