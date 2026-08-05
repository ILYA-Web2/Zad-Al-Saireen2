enum TasbihPhase { allahuAkbar, alhamdulillah, subhanAllah }

extension TasbihPhaseX on TasbihPhase {
  String get label {
    switch (this) {
      case TasbihPhase.allahuAkbar:
        return 'الله أكبر';
      case TasbihPhase.alhamdulillah:
        return 'الحمد لله';
      case TasbihPhase.subhanAllah:
        return 'سبحان الله';
    }
  }

  int get target {
    switch (this) {
      case TasbihPhase.allahuAkbar:
        return 34;
      case TasbihPhase.alhamdulillah:
        return 33;
      case TasbihPhase.subhanAllah:
        return 33;
    }
  }

  TasbihPhase get next {
    switch (this) {
      case TasbihPhase.allahuAkbar:
        return TasbihPhase.alhamdulillah;
      case TasbihPhase.alhamdulillah:
        return TasbihPhase.subhanAllah;
      case TasbihPhase.subhanAllah:
        return TasbihPhase.allahuAkbar;
    }
  }
}
