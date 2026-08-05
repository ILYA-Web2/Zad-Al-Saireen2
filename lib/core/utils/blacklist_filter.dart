import '../constants/app_constants.dart';

class BlacklistFilter {
  BlacklistFilter._();

  /// Layer 3 — checked on the query itself, before any network call, so
  /// an obviously abusive search never even spends bandwidth or API quota.
  static bool isQueryExplicitlyBlocked(String query) {
    final q = query.toLowerCase();
    return AppConstants.explicitBlockTerms.any((term) => q.contains(term));
  }

  /// Layer 2 — a result must contain at least one religious token in its
  /// title/description to be shown, AND must not contain an explicitly
  /// blacklisted (sectarian/entertainment/political) term. This is what
  /// actually stops non-religious or abusive content from appearing,
  /// without needing to guess every possible bad word — the app only has
  /// to recognize what religious content *is*, not enumerate everything
  /// it isn't.
  static bool isContentAllowed(String title, String description) {
    final combined = '${title.toLowerCase()} ${description.toLowerCase()}';

    for (final term in AppConstants.explicitBlockTerms) {
      if (combined.contains(term)) return false;
    }
    for (final word in AppConstants.contentBlacklist) {
      if (combined.contains(word)) return false;
    }
    return AppConstants.religiousTokens.any((token) => combined.contains(token));
  }

  static List<String> buildAlternativeSuggestions(String failedQuery) {
    final suggestions = <String>[];
    for (final keyword in AppConstants.hussainiKeywords) {
      if (!keyword.contains(failedQuery)) {
        suggestions.add(keyword);
      }
      if (suggestions.length >= 5) break;
    }
    suggestions.addAll([
      'لطميات باسم الكربلائي',
      'قصائد أحمد الساعدي',
      'أدعية الإمام الحسين',
    ]);
    return suggestions.take(5).toList();
  }

  /// Only strips explicitly blacklisted words — never rewrites the query
  /// into something else. Content safety is enforced on the *results* via
  /// [isContentAllowed] and [isQueryExplicitlyBlocked], not by
  /// second-guessing what the person typed; that's what previously broke
  /// searches for a reciter's own name or a specific, less-common Dua.
  static String sanitizeQuery(String query) {
    String sanitized = query.trim();
    for (final word in AppConstants.contentBlacklist) {
      sanitized = sanitized.replaceAll(word, '').trim();
    }
    if (sanitized.isEmpty) {
      return AppConstants.hussainiKeywords.isNotEmpty
          ? AppConstants.hussainiKeywords.first
          : 'لطميات حسينية';
    }
    return sanitized;
  }
}
