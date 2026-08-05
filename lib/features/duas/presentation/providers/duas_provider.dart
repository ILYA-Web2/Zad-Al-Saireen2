import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/duas_local_data_source.dart';
import '../../data/models/dua_model.dart';

final allDuasProvider = Provider<List<DuaModel>>((ref) {
  return DuasLocalDataSource.allDuas;
});

final duaByIdProvider = Provider.family<DuaModel?, String>((ref, id) {
  return DuasLocalDataSource.getById(id);
});

// ─── Reader display preferences (shared with Quran settings) ──────────────────
final duaFontSizeProvider = StateProvider<double>((ref) => 20.0);
final duaNightModeProvider = StateProvider<bool>((ref) => false);
