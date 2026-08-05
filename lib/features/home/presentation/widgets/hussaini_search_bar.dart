import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class HussainiSearchBar extends StatefulWidget {
  const HussainiSearchBar({
    super.key,
    required this.onSearch,
    this.recentSearches = const [],
    this.onRemoveSearch,
    this.onClearSearches,
  });

  final void Function(String query) onSearch;
  final List<String> recentSearches;
  final void Function(String query)? onRemoveSearch;
  final VoidCallback? onClearSearches;

  @override
  State<HussainiSearchBar> createState() => _HussainiSearchBarState();
}

class _HussainiSearchBarState extends State<HussainiSearchBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _expandController;
  late final Animation<double> _widthAnimation;
  late final Animation<double> _glowAnimation;
  bool _isFocused = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _widthAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeOut),
    );
    _glowAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOut,
    );
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _expandController.forward();
      setState(() => _showSuggestions = true);
    } else {
      _expandController.reverse();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showSuggestions = false);
      });
    }
  }

  void _onSubmit(String query) {
    if (query.trim().isEmpty) return;
    _focusNode.unfocus();
    widget.onSearch(query.trim());
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    _focusNode.unfocus();
    widget.onSearch(suggestion);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        // ── Islamic ornamental frame around search ───────────────────────────
        Stack(
          alignment: Alignment.center,
          children: [
            // Focus highlight — a flat animated border instead of a
            // blurred glow, per the no-glow/no-shadow visual direction.
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) => Container(
                width: screenWidth - 24,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.35 * _glowAnimation.value),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // Search field
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: screenWidth - 24,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isFocused
                        ? AppColors.glassFill.withOpacity(0.12)
                        : AppColors.glassFill,
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius),
                    border: Border.all(
                      color: _isFocused
                          ? AppColors.accent.withOpacity(0.7)
                          : AppColors.glassBorder,
                      width: _isFocused ? 1.6 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: _isFocused
                            ? AppColors.accent
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن قصائد أو لطميات أو أدعية...',
                            hintStyle: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onSubmitted: _onSubmit,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _controller.clear();
                            setState(() {});
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.close_rounded,
                                size: 18, color: AppColors.textMuted),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => _onSubmit(_controller.text),
                        child: Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                  AppConstants.borderRadius),
                              bottomLeft: Radius.circular(
                                  AppConstants.borderRadius),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // ── Search Suggestions (YouTube-style vertical list) ────────────────
        if (_showSuggestions && widget.recentSearches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: screenWidth - 24,
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in widget.recentSearches.take(8))
                  _RecentSearchRow(
                    label: s,
                    onTap: () => _onSuggestionTap(s),
                    onRemove: widget.onRemoveSearch == null
                        ? null
                        : () => widget.onRemoveSearch!(s),
                  ),
                if (widget.onClearSearches != null)
                  GestureDetector(
                    onTap: widget.onClearSearches,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'مسح كل السجل',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2, end: 0),

        // ── Default keyword chips (when not focused) ─────────────────────────
        if (!_showSuggestions)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: AppConstants.hussainiKeywords
                  .take(8)
                  .map(
                    (keyword) => _SuggestionChip(
                      label: keyword,
                      onTap: () => _onSuggestionTap(keyword),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/// One row of the YouTube-style recent-search dropdown: a clock/history
/// glyph, the query text (fills the remaining width, ellipsized rather
/// than wrapped so the row height never stretches), and — only when a
/// removal handler was actually provided — a small X to delete just that
/// entry without clearing the whole list.
class _RecentSearchRow extends StatelessWidget {
  const _RecentSearchRow({
    required this.label,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.glassBorder, width: 1.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
