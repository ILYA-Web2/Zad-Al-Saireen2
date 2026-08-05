class SurahEntity {
  const SurahEntity({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  bool get isMeccan => revelationType == 'Meccan';
  String get revelationTypeArabic => isMeccan ? 'مكية' : 'مدنية';
}

class AyahEntity {
  const AyahEntity({
    required this.number,
    required this.numberInSurah,
    required this.text,
    required this.surahNumber,
    required this.juz,
    required this.page,
  });

  final int number;
  final int numberInSurah;
  final String text;
  final int surahNumber;
  final int juz;
  final int page;
}

class ReciterEntity {
  const ReciterEntity({
    required this.name,
    required this.code,
    required this.edition,
  });

  final String name;
  final String code;
  final String edition;
}
