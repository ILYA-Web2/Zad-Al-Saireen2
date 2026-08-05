class ShiaEvent {
  const ShiaEvent({
    required this.title,
    required this.day,
    required this.month,
    required this.type,
    this.description = '',
  });

  final String title;
  final int day;
  final int month;
  final ShiaEventType type;
  final String description;
}

enum ShiaEventType { martyrdom, birthday, celebration, occasion, sadness }

extension ShiaEventTypeX on ShiaEventType {
  String get label {
    switch (this) {
      case ShiaEventType.martyrdom:
        return 'شهادة';
      case ShiaEventType.birthday:
        return 'ولادة';
      case ShiaEventType.celebration:
        return 'عيد';
      case ShiaEventType.occasion:
        return 'مناسبة';
      case ShiaEventType.sadness:
        return 'مصيبة';
    }
  }
}

class ShiaEventsLocalDataSource {
  ShiaEventsLocalDataSource._();

  static const List<ShiaEvent> allEvents = [
    // ─── محرم ────────────────────────────────────────────────────────────────
    ShiaEvent(title: 'عاشوراء — استشهاد الإمام الحسين عليه السلام', day: 10, month: 1, type: ShiaEventType.martyrdom, description: 'ذكرى استشهاد سيد الشهداء الإمام الحسين بن علي عليه السلام وأصحابه الكرام في كربلاء المقدسة سنة 61 هـ'),
    ShiaEvent(title: 'بداية محرم الحرام', day: 1, month: 1, type: ShiaEventType.occasion, description: 'بداية السنة الهجرية الجديدة وأول أيام الأشهر الحرم'),
    ShiaEvent(title: 'ذكرى رحيل قافلة الحسين من المدينة', day: 3, month: 1, type: ShiaEventType.sadness),
    ShiaEvent(title: 'مجيء أهل البيت إلى الكوفة بعد كربلاء', day: 12, month: 1, type: ShiaEventType.occasion),
    ShiaEvent(title: 'أربعين الإمام الحسين عليه السلام', day: 20, month: 2, type: ShiaEventType.occasion, description: 'ذكرى أربعين يوماً على استشهاد الإمام الحسين عليه السلام وهي من أعظم الشعائر الحسينية'),

    // ─── صفر ─────────────────────────────────────────────────────────────────
    ShiaEvent(title: 'شهادة الإمام علي بن الحسين زين العابدين', day: 25, month: 2, type: ShiaEventType.martyrdom, description: 'استشهاد رابع الأئمة الإمام علي بن الحسين زين العابدين عليه السلام'),
    ShiaEvent(title: 'شهادة الإمام الحسن المجتبى عليه السلام', day: 28, month: 2, type: ShiaEventType.martyrdom, description: 'استشهاد الإمام الحسن بن علي المجتبى عليه السلام سنة 50 هـ'),
    ShiaEvent(title: 'وفاة النبي محمد صلى الله عليه وآله', day: 28, month: 2, type: ShiaEventType.occasion, description: 'ذكرى وفاة النبي الأكرم محمد بن عبدالله صلى الله عليه وآله'),

    // ─── ربيع الأول ──────────────────────────────────────────────────────────
    ShiaEvent(title: 'شهادة الإمام علي الهادي عليه السلام', day: 3, month: 3, type: ShiaEventType.martyrdom),
    ShiaEvent(title: 'المولد النبوي الشريف', day: 17, month: 3, type: ShiaEventType.birthday, description: 'ولادة النبي الأكرم محمد بن عبدالله صلى الله عليه وآله وسلم — ويصادف ولادة الإمام الصادق عليه السلام'),
    ShiaEvent(title: 'ولادة الإمام الصادق عليه السلام', day: 17, month: 3, type: ShiaEventType.birthday, description: 'ولادة سادس الأئمة الإمام جعفر بن محمد الصادق عليه السلام'),

    // ─── ربيع الثاني ─────────────────────────────────────────────────────────
    ShiaEvent(title: 'ولادة الإمام الحسن العسكري عليه السلام', day: 8, month: 4, type: ShiaEventType.birthday),
    ShiaEvent(title: 'وفاة السيدة زينب الكبرى عليها السلام', day: 15, month: 4, type: ShiaEventType.occasion),

    // ─── جمادى الأولى ────────────────────────────────────────────────────────
    ShiaEvent(title: 'شهادة السيدة فاطمة الزهراء عليها السلام', day: 3, month: 5, type: ShiaEventType.martyrdom, description: 'الرواية المشهورة في استشهاد سيدة نساء العالمين فاطمة الزهراء بنت النبي صلى الله عليه وآله'),
    ShiaEvent(title: 'ولادة السيدة زينب الكبرى عليها السلام', day: 5, month: 5, type: ShiaEventType.birthday),
    ShiaEvent(title: 'شهادة الإمام محمد الباقر عليه السلام', day: 7, month: 5, type: ShiaEventType.martyrdom),

    // ─── جمادى الثانية ───────────────────────────────────────────────────────
    ShiaEvent(title: 'ولادة السيدة فاطمة الزهراء عليها السلام', day: 20, month: 6, type: ShiaEventType.birthday, description: 'ولادة سيدة نساء العالمين فاطمة بنت النبي صلى الله عليه وآله'),

    // ─── رجب ─────────────────────────────────────────────────────────────────
    ShiaEvent(title: 'ولادة الإمام علي بن أبي طالب عليه السلام', day: 13, month: 7, type: ShiaEventType.birthday, description: 'ولادة أمير المؤمنين الإمام علي بن أبي طالب عليه السلام في الكعبة المشرفة'),
    ShiaEvent(title: 'المبعث النبوي الشريف', day: 27, month: 7, type: ShiaEventType.celebration, description: 'ذكرى نزول الوحي على النبي الأكرم صلى الله عليه وآله وبداية الرسالة الإسلامية'),
    ShiaEvent(title: 'ولادة الإمام الكاظم عليه السلام', day: 7, month: 7, type: ShiaEventType.birthday),
    ShiaEvent(title: 'شهادة الإمام الكاظم عليه السلام', day: 25, month: 7, type: ShiaEventType.martyrdom, description: 'استشهاد سابع الأئمة الإمام موسى بن جعفر الكاظم عليه السلام'),

    // ─── شعبان ───────────────────────────────────────────────────────────────
    ShiaEvent(title: 'ولادة الإمام الحسين عليه السلام', day: 3, month: 8, type: ShiaEventType.birthday, description: 'ولادة سيد الشهداء الإمام الحسين بن علي عليه السلام'),
    ShiaEvent(title: 'ولادة الإمام العباس بن علي عليه السلام', day: 4, month: 8, type: ShiaEventType.birthday),
    ShiaEvent(title: 'ولادة الإمام علي بن الحسين زين العابدين', day: 5, month: 8, type: ShiaEventType.birthday),
    ShiaEvent(title: 'ولادة الإمام المهدي المنتظر عجل الله فرجه', day: 15, month: 8, type: ShiaEventType.birthday, description: 'ولادة الحجة بن الحسن المهدي المنتظر عجل الله تعالى فرجه الشريف في سامراء سنة 255 هـ'),
    ShiaEvent(title: 'ليلة النصف من شعبان', day: 15, month: 8, type: ShiaEventType.occasion, description: 'ليلة مباركة تحيا فيها الأدعية والمناجاة'),

    // ─── رمضان ───────────────────────────────────────────────────────────────
    ShiaEvent(title: 'بداية شهر رمضان المبارك', day: 1, month: 9, type: ShiaEventType.occasion),
    ShiaEvent(title: 'ليلة القدر (الاحتمال الأول)', day: 19, month: 9, type: ShiaEventType.occasion),
    ShiaEvent(title: 'شهادة الإمام علي بن أبي طالب عليه السلام', day: 21, month: 9, type: ShiaEventType.martyrdom, description: 'استشهاد أمير المؤمنين الإمام علي عليه السلام في محراب مسجد الكوفة على يد ابن ملجم سنة 40 هـ'),
    ShiaEvent(title: 'ليلة القدر (الاحتمال الثاني)', day: 21, month: 9, type: ShiaEventType.occasion),
    ShiaEvent(title: 'ليلة القدر (الاحتمال الأرجح)', day: 23, month: 9, type: ShiaEventType.occasion),

    // ─── شوال ────────────────────────────────────────────────────────────────
    ShiaEvent(title: 'عيد الفطر المبارك', day: 1, month: 10, type: ShiaEventType.celebration, description: 'أول أيام عيد الفطر المبارك — فرحة المسلمين بختام شهر رمضان'),
    ShiaEvent(title: 'شهادة الإمام الصادق عليه السلام', day: 25, month: 10, type: ShiaEventType.martyrdom, description: 'استشهاد سادس الأئمة الإمام جعفر بن محمد الصادق عليه السلام'),

    // ─── ذو القعدة ───────────────────────────────────────────────────────────
    ShiaEvent(title: 'ولادة الإمام الرضا عليه السلام', day: 11, month: 11, type: ShiaEventType.birthday),
    ShiaEvent(title: 'ولادة الإمام محمد الجواد عليه السلام', day: 10, month: 11, type: ShiaEventType.birthday),

    // ─── ذو الحجة ────────────────────────────────────────────────────────────
    ShiaEvent(title: 'عيد الأضحى المبارك', day: 10, month: 12, type: ShiaEventType.celebration),
    ShiaEvent(title: 'عيد الغدير الأغر', day: 18, month: 12, type: ShiaEventType.celebration, description: 'ذكرى إعلان النبي صلى الله عليه وآله ولاية الإمام علي عليه السلام في غدير خم — من أعظم الأعياد الإسلامية'),
    ShiaEvent(title: 'شهادة الإمام الرضا عليه السلام', day: 17, month: 12, type: ShiaEventType.martyrdom, description: 'استشهاد ثامن الأئمة الإمام علي بن موسى الرضا عليه السلام'),
    ShiaEvent(title: 'شهادة الإمام الجواد عليه السلام', day: 30, month: 11, type: ShiaEventType.martyrdom),
    ShiaEvent(title: 'شهادة الإمام العسكري عليه السلام', day: 8, month: 3, type: ShiaEventType.martyrdom, description: 'استشهاد الإمام الحسن العسكري عليه السلام أحد عشر الأئمة'),
    ShiaEvent(title: 'يوم عرفة', day: 9, month: 12, type: ShiaEventType.occasion, description: 'يوم الوقوف في عرفات — دعاء عرفة للإمام الحسين عليه السلام'),
  ];

  static List<ShiaEvent> getEventsForMonth(int month) =>
      allEvents.where((e) => e.month == month).toList()
        ..sort((a, b) => a.day.compareTo(b.day));

  static List<ShiaEvent> getEventsForDay(int day, int month) =>
      allEvents.where((e) => e.day == day && e.month == month).toList();

  static ShiaEvent? getNextEvent(int currentDay, int currentMonth) {
    final remaining = allEvents
        .where((e) =>
            e.month > currentMonth ||
            (e.month == currentMonth && e.day >= currentDay))
        .toList()
      ..sort((a, b) {
        if (a.month != b.month) return a.month.compareTo(b.month);
        return a.day.compareTo(b.day);
      });
    if (remaining.isNotEmpty) return remaining.first;

    // Nothing left in the current Hijri year (e.g. today is after the
    // last event in Dhu al-Hijjah) — wrap around to the earliest event
    // of next year instead of returning null.
    if (allEvents.isEmpty) return null;
    final wrapped = List<ShiaEvent>.from(allEvents)
      ..sort((a, b) {
        if (a.month != b.month) return a.month.compareTo(b.month);
        return a.day.compareTo(b.day);
      });
    return wrapped.first;
  }

  static const List<String> hijriMonthNames = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
    'جمادى الأولى', 'جمادى الثانية', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];
}
