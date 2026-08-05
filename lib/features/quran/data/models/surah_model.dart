import '../../domain/entities/surah_entity.dart';

class SurahModel extends SurahEntity {
  const SurahModel({
    required super.number,
    required super.name,
    required super.englishName,
    required super.englishNameTranslation,
    required super.numberOfAyahs,
    required super.revelationType,
  });

  factory SurahModel.fromJson(Map<String, dynamic> json) {
    return SurahModel(
      number: json['number'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      englishName: json['englishName']?.toString() ?? '',
      englishNameTranslation:
          json['englishNameTranslation']?.toString() ?? '',
      numberOfAyahs: json['numberOfAyahs'] as int? ?? 0,
      revelationType: json['revelationType']?.toString() ?? 'Meccan',
    );
  }
}

class AyahModel extends AyahEntity {
  const AyahModel({
    required super.number,
    required super.numberInSurah,
    required super.text,
    required super.surahNumber,
    required super.juz,
    required super.page,
  });

  factory AyahModel.fromJson(Map<String, dynamic> json, int surahNumber) {
    return AyahModel(
      number: json['number'] as int? ?? 0,
      numberInSurah: json['numberInSurah'] as int? ?? 0,
      text: json['text']?.toString() ?? '',
      surahNumber: surahNumber,
      juz: json['juz'] as int? ?? 1,
      page: json['page'] as int? ?? 1,
    );
  }
}
