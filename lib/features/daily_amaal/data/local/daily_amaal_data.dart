class DailyAmaalModel {
  const DailyAmaalModel({
    required this.dayName,
    required this.arabicDay,
    required this.acts,
    required this.dua,
    required this.surahRecommendation,
    this.specialNote = '',
  });

  final String dayName;
  final String arabicDay;
  final List<AmaalAct> acts;
  final String dua;
  final String surahRecommendation;
  final String specialNote;
}

class AmaalAct {
  const AmaalAct({
    required this.title,
    required this.description,
    required this.reward,
  });

  final String title;
  final String description;
  final String reward;
}

class DailyAmaalLocalDataSource {
  DailyAmaalLocalDataSource._();

  /// [weekday] follows Dart convention: Monday=1, ..., Sunday=7
  static DailyAmaalModel getForWeekday(int weekday) {
    return _weeklyAmaal[weekday - 1];
  }

  static DailyAmaalModel getToday() =>
      getForWeekday(DateTime.now().weekday);

  static const List<DailyAmaalModel> _weeklyAmaal = [
    // ── الاثنين ──────────────────────────────────────────────────────────────
    DailyAmaalModel(
      dayName: 'Monday',
      arabicDay: 'الاثنين',
      dua: 'اللَّهُمَّ إِنَّكَ تَعْلَمُ سِرِّي وَعَلَانِيَتِي فَاقْبَلْ مَعْذِرَتِي، وَتَعْلَمُ حَاجَتِي فَأَعْطِنِي سُؤْلِي.',
      surahRecommendation: 'سورة يس',
      acts: [
        AmaalAct(
          title: 'صلاة النوافل الليلية',
          description: 'صلاة ركعتين بعد المغرب، يُقرأ في كل ركعة الفاتحة وقل هو الله أحد.',
          reward: 'يُكتب لصاحبها أجر الشهداء',
        ),
        AmaalAct(
          title: 'قراءة سورة يس',
          description: 'تلاوة سورة يس بعد صلاة الصبح أو في أي وقت من اليوم.',
          reward: 'تعدل عشر قراءات للقرآن الكريم',
        ),
        AmaalAct(
          title: 'الصدقة على الفقراء',
          description: 'إخراج الصدقة ولو بشيء يسير في هذا اليوم.',
          reward: 'دفع البلاء وزيادة الرزق',
        ),
        AmaalAct(
          title: 'الصلاة على النبي وآله',
          description: 'إكثار الصلاة على النبي الأكرم وآله الطاهرين في هذا اليوم.',
          reward: 'رفع الدرجات وتكفير السيئات',
        ),
      ],
    ),

    // ── الثلاثاء ─────────────────────────────────────────────────────────────
    DailyAmaalModel(
      dayName: 'Tuesday',
      arabicDay: 'الثلاثاء',
      dua: 'اللَّهُمَّ اجْعَلْ أَوَّلَ يَوْمِي هَذَا صَلَاحًا، وَأَوْسَطَهُ فَلَاحًا، وَآخِرَهُ نَجَاحًا.',
      surahRecommendation: 'سورة آل عمران',
      acts: [
        AmaalAct(
          title: 'زيارة الإمام الحسين عليه السلام',
          description: 'قراءة زيارة الإمام الحسين من بعيد أو التوجه إليها بالقلب والنية.',
          reward: 'كأجر زيارة حقيقية',
        ),
        AmaalAct(
          title: 'قراءة آية الكرسي مائة مرة',
          description: 'تكرار آية الكرسي مئة مرة بعد صلاة الصبح أو قبل النوم.',
          reward: 'حماية من الشياطين وأمان في اليوم',
        ),
        AmaalAct(
          title: 'صيام التطوع',
          description: 'يُستحب صيام الثلاثاء فيه فضل كبير.',
          reward: 'يكفر ذنوب سبعة أشهر',
        ),
      ],
    ),

    // ── الأربعاء ─────────────────────────────────────────────────────────────
    DailyAmaalModel(
      dayName: 'Wednesday',
      arabicDay: 'الأربعاء',
      dua: 'اللَّهُمَّ أَغْنِنِي بِحَلَالِكَ عَنْ حَرَامِكَ، وَبِطَاعَتِكَ عَنْ مَعْصِيَتِكَ، وَبِفَضْلِكَ عَمَّنْ سِوَاكَ.',
      surahRecommendation: 'سورة الكهف',
      specialNote: 'يوم مكروه للبدء بالسفر، والأفضل الإكثار من الاستغفار',
      acts: [
        AmaalAct(
          title: 'قراءة سورة الكهف',
          description: 'يُستحب قراءة سورة الكهف كاملة في هذا اليوم.',
          reward: 'نور بين الجمعتين وأمان من فتنة الدجال',
        ),
        AmaalAct(
          title: 'الاستغفار سبعين مرة',
          description: 'أن يقول المؤمن: أستغفر الله وأتوب إليه سبعين مرة.',
          reward: 'مغفرة الذنوب وإن كانت مثل زبد البحر',
        ),
        AmaalAct(
          title: 'تلاوة الأدعية المأثورة',
          description: 'قراءة دعاء كميل إن أمكن أو أي دعاء مأثور عن أهل البيت.',
          reward: 'تقرب إلى الله وإجابة الدعاء',
        ),
      ],
    ),

    // ── الخميس ───────────────────────────────────────────────────────────────
    DailyAmaalModel(
      dayName: 'Thursday',
      arabicDay: 'الخميس',
      dua: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ بِرَحْمَتِكَ الَّتِي وَسِعَتْ كُلَّ شَيْءٍ أَنْ تَغْفِرَ لِي ذُنُوبِي.',
      surahRecommendation: 'سورة الجمعة والمنافقون',
      specialNote: 'يوم مبارك يُستحب فيه الزواج والسفر',
      acts: [
        AmaalAct(
          title: 'الغسل التهيؤي يوم الجمعة',
          description: 'يجوز الاغتسال ليلة الجمعة أو يوم الخميس تهيؤاً ليوم الجمعة.',
          reward: 'طهارة وتجهيز للقاء يوم الجمعة المبارك',
        ),
        AmaalAct(
          title: 'صلاة ليلة الجمعة',
          description: 'يُستحب إحياء ليلة الجمعة بالصلاة والدعاء والتلاوة.',
          reward: 'شفاعة النبي وآله يوم القيامة',
        ),
        AmaalAct(
          title: 'قراءة الصلوات على النبي وآله',
          description: 'الإكثار من الصلاة على محمد وآل محمد يوم الخميس وليلته.',
          reward: 'رفع الحساب وتخفيف ثقل الميزان',
        ),
        AmaalAct(
          title: 'أداء حوائج المؤمنين',
          description: 'السعي في قضاء حوائج إخوانك المؤمنين في هذا اليوم.',
          reward: 'أفضل من ألف صلاة نافلة',
        ),
      ],
    ),

    // ── الجمعة ───────────────────────────────────────────────────────────────
    DailyAmaalModel(
      dayName: 'Friday',
      arabicDay: 'الجمعة',
      dua: 'اللَّهُمَّ اجْعَلْ شِيعَتَنَا وَمَوَالِيَنَا مِنَ الَّذِينَ يَخَافُونَكَ، وَيَرْجُونَكَ، وَيُحِبُّونَكَ.',
      surahRecommendation: 'سورة الجمعة، الكهف، الدخان',
      specialNote: 'سيد الأيام وخير يوم طلعت فيه الشمس',
      acts: [
        AmaalAct(
          title: 'غسل الجمعة',
          description: 'أداء غسل الجمعة المستحب قبل الظهر.',
          reward: 'كفارة ذنوب الأسبوع وطهارة روحية',
        ),
        AmaalAct(
          title: 'قراءة سورة الكهف',
          description: 'تلاوة سورة الكهف يوم الجمعة.',
          reward: 'نور من الجمعة إلى الجمعة',
        ),
        AmaalAct(
          title: 'صلاة الجمعة أو الظهرين',
          description: 'أداء صلاة الجمعة بإمام عادل أو الظهرين في زمن الغيبة.',
          reward: 'عبادة كأفضل الأعمال',
        ),
        AmaalAct(
          title: 'زيارة الإمام الحسين عليه السلام',
          description: 'قراءة زيارة الإمام الحسين — يوم الجمعة يوم الزيارة.',
          reward: 'أجر الحج والعمرة',
        ),
        AmaalAct(
          title: 'الصدقة والإطعام',
          description: 'إطعام المحتاجين أو التصدق في هذا اليوم المبارك.',
          reward: 'مضاعفة الثواب أضعافاً كثيرة',
        ),
        AmaalAct(
          title: 'الدعاء للإمام المهدي',
          description: 'الدعاء لتعجيل فرج الإمام المهدي المنتظر عجل الله فرجه.',
          reward: 'المشاركة في خير الانتظار',
        ),
      ],
    ),

    // ── السبت ────────────────────────────────────────────────────────────────
    DailyAmaalModel(
      dayName: 'Saturday',
      arabicDay: 'السبت',
      dua: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَآلِ مُحَمَّدٍ وَاجْعَلْنَا مِنَ التَّوَّابِينَ وَاجْعَلْنَا مِنَ الْمُتَطَهِّرِينَ.',
      surahRecommendation: 'سورة الفاتحة وآيات الحرز',
      acts: [
        AmaalAct(
          title: 'زيارة أمير المؤمنين',
          description: 'يوم السبت يُستحب فيه زيارة الإمام علي عليه السلام أو قراءة زيارته.',
          reward: 'كفارة الذنوب وزيادة الإيمان',
        ),
        AmaalAct(
          title: 'قراءة التسبيحات الأربع',
          description: 'تكرار سبحان الله والحمد لله ولا إله إلا الله والله أكبر مئة مرة.',
          reward: 'تسبيح الجبال والبحار يشهد لصاحبه',
        ),
        AmaalAct(
          title: 'الذكر والتهليل',
          description: 'الإكثار من ذكر لا إله إلا الله، محمد رسول الله، علي ولي الله.',
          reward: 'رسوخ الإيمان وثبات اليقين',
        ),
      ],
    ),

    // ── الأحد ────────────────────────────────────────────────────────────────
    DailyAmaalModel(
      dayName: 'Sunday',
      arabicDay: 'الأحد',
      dua: 'اللَّهُمَّ هَذَا يَوْمٌ جَدِيدٌ وَعَلَيَّ فِيهِ شُهُودٌ جُدُدٌ، فَاجْعَلْ عَمَلِي فِيهِ خَيْرًا وَمَوْقِفِي فِيهِ حَسَنًا.',
      surahRecommendation: 'سورة البقرة (الآيات الأولى)',
      acts: [
        AmaalAct(
          title: 'صيام الأيام البيض',
          description: 'إن وافق يومٌ من السبت أو الأحد أيامَ البيض (13 و14 و15 من الشهر) فصيامها مستحب.',
          reward: 'كأجر صيام الدهر',
        ),
        AmaalAct(
          title: 'زيارة الإمام الرضا عليه السلام',
          description: 'يُستحب زيارة الإمام الرضا أو قراءة زيارته يوم الأحد.',
          reward: 'بركة في الأسبوع القادم',
        ),
        AmaalAct(
          title: 'تلاوة الكرسي والمعوذتين',
          description: 'قراءة آية الكرسي والمعوذتين ثلاث مرات بعد صلاة الصبح.',
          reward: 'أمان من كل سوء حتى الأسبوع القادم',
        ),
        AmaalAct(
          title: 'صلة الأرحام',
          description: 'التواصل مع الأقارب والأهل بزيارة أو اتصال.',
          reward: 'زيادة العمر والرزق ومحبة الناس',
        ),
      ],
    ),
  ];
}
