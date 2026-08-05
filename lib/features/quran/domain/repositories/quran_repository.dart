import '../entities/surah_entity.dart';

abstract class QuranRepository {
  Future<List<SurahEntity>> getAllSurahs();
  Future<List<AyahEntity>> getSurahAyahs(int surahNumber);
  Future<List<AyahEntity>> searchAyahs(String query);
}
