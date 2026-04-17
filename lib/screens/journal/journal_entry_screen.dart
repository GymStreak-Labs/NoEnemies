import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/journal_entry.dart';
import '../../models/user_profile.dart';
import '../../providers/journey_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/stage_particles.dart';

/// A single journal page. Written in a cinematic tome style — amber-on-black,
/// display serif title, monospace-leaning body. Uses auto-save on navigation
/// away rather than forcing a tap on the Save button.
class JournalEntryScreen extends StatefulWidget {
  final String? entryId;

  const JournalEntryScreen({super.key, this.entryId});

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocus = FocusNode();
  JournalEntry? _existingEntry;
  bool _isEditing = false;
  DateTime _pageDate = DateTime.now();

  /// Mentor reflection on the saved entry. Non-blocking — fetched after
  /// a successful Save tap and surfaced as a card below the body.
  String? _mentorReflection;
  bool _loadingReflection = false;

  @override
  void initState() {
    super.initState();
    if (widget.entryId != null) {
      _isEditing = true;
      final entries = context.read<UserProvider>().journalEntries;
      _existingEntry =
          entries.where((e) => e.id == widget.entryId).firstOrNull;
      if (_existingEntry != null) {
        _titleController.text = _existingEntry!.title;
        _contentController.text = _existingEntry!.content;
        _pageDate = _existingEntry!.date;
      }
    }
    // Live-update word count as the user writes.
    _contentController.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _contentFocus.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save({bool pop = true}) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      if (pop && mounted) context.pop();
      return;
    }

    final userProvider = context.read<UserProvider>();
    final journeyProvider = context.read<JourneyProvider>();

    if (_isEditing && _existingEntry != null) {
      await userProvider.updateJournalEntry(
        _existingEntry!.copyWith(
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
        ),
      );
    } else {
      await userProvider.addJournalEntry(
        title: title.isEmpty ? 'Untitled' : title,
        content: content,
      );
    }
    HapticFeedback.selectionClick();

    // If the caller is NOT popping the screen, fetch a mentor reflection
    // asynchronously so it can appear below the entry. Popping means the
    // user is navigating away — skip the reflection to save tokens.
    if (!pop && content.isNotEmpty) {
      final profile = userProvider.profile;
      if (profile != null) {
        setState(() {
          _loadingReflection = true;
          _mentorReflection = null;
        });
        () async {
          try {
            final reflection = await journeyProvider.generateJournalReflection(
              profile: profile,
              entryText: content,
              context: userProvider.aiContext,
            );
            if (!mounted) return;
            setState(() {
              _mentorReflection = reflection;
              _loadingReflection = false;
            });
          } catch (_) {
            if (!mounted) return;
            setState(() {
              _loadingReflection = false;
            });
          }
        }();
      }
    }

    if (pop && mounted) context.pop();
  }

  void _delete() {
    if (_existingEntry == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.war.withValues(alpha: 0.3),
          ),
        ),
        title: Text(
          'Delete this page?',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'The ink cannot be restored once washed away.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Keep',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context
                  .read<UserProvider>()
                  .deleteJournalEntry(_existingEntry!.id);
              if (mounted) context.pop();
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.war,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    // Grab the provider synchronously so we don't cross async gaps with
    // BuildContext — the provider outlives this widget.
    final provider = context.read<UserProvider>();
    if (_existingEntry == null) {
      // New, unsaved entry — save first, then bookmark the newly persisted
      // entry (which becomes the first in the list).
      await _save(pop: false);
      final latest = provider.journalEntries.firstOrNull;
      if (latest == null) return;
      await provider.toggleBookmark(latest.id);
      if (!mounted) return;
      setState(() {
        _existingEntry = provider.journalEntries
            .where((e) => e.id == latest.id)
            .firstOrNull;
        _isEditing = true;
      });
      HapticFeedback.mediumImpact();
      return;
    }
    await provider.toggleBookmark(_existingEntry!.id);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _existingEntry = provider.journalEntries
          .where((e) => e.id == widget.entryId)
          .firstOrNull;
    });
  }

  int get _wordCount {
    final t = _contentController.text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<UserProvider>().profile?.currentTitle ??
        UserTitle.warrior;
    final isBookmarked = _existingEntry?.isBookmarked ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      // Prevent bottom viewInset squashing the body so the keyboard cleanly
      // pushes the text field instead of rebuilding the stack.
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Candlelight halo from above the page.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.3,
                  colors: [
                    (isBookmarked
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.7))
                        .withValues(alpha: isBookmarked ? 0.12 : 0.07),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: StageParticles(
              title: stage,
              particleCount: 10,
              opacity: 0.18,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  isEditing: _isEditing,
                  isBookmarked: isBookmarked,
                  onBack: () => _save(pop: true),
                  onToggleBookmark: _toggleBookmark,
                  onDelete: _isEditing ? _delete : null,
                  onSave: () => _save(pop: true),
                ),

                // Page date & bookmark hint
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 4, 26, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEEE · MMMM d, yyyy').format(_pageDate),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (isBookmarked)
                        Row(
                          children: [
                            Icon(
                              Icons.bookmark_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'IN THE BOOK OF PEACE',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 2,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 300.ms),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // The page itself — a single flowing column with title + body
                // living on the same "sheet", separated by a thin hairline.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 0, 26, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextField(
                          controller: _titleController,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.15,
                          ),
                          cursorColor: AppColors.primary,
                          maxLines: 2,
                          minLines: 1,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _contentFocus.requestFocus(),
                          decoration: InputDecoration(
                            hintText: 'Title this page…',
                            hintStyle: GoogleFonts.cormorantGaramond(
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary
                                  .withValues(alpha: 0.5),
                              fontStyle: FontStyle.italic,
                              height: 1.15,
                            ),
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Hairline with amber fade — the margin of the page.
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.4),
                                AppColors.primary.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Body
                        Expanded(
                          child: TextField(
                            controller: _contentController,
                            focusNode: _contentFocus,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            cursorColor: AppColors.primary,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              height: 1.75,
                              letterSpacing: 0.15,
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.95),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Let the ink run…',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 16,
                                height: 1.75,
                                color: AppColors.textTertiary
                                    .withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                              ),
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Optional mentor reflection card — only appears after the
                // user explicitly asks for one (tap "Reflect"). Non-blocking,
                // and dismissible by navigating away.
                if (_loadingReflection || _mentorReflection != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 8, 26, 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.08),
                            AppColors.accent.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: AppColors.primary,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'MENTOR',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_loadingReflection)
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat())
                                    .fadeOut(duration: 700.ms)
                                    .then()
                                    .fadeIn(duration: 700.ms),
                                const SizedBox(width: 8),
                                Text(
                                  'Reading your words…',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              _mentorReflection!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.6,
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.9),
                                fontStyle: FontStyle.italic,
                              ),
                            ).animate().fadeIn(duration: 500.ms),
                        ],
                      ),
                    ),
                  ),

                // Footer — live word count + subtle reminder that bookmarked
                // entries join the Book of Peace. Also hosts the Reflect CTA.
                Container(
                  padding: const EdgeInsets.fromLTRB(26, 10, 26, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$_wordCount words',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_wordCount > 0 &&
                          _mentorReflection == null &&
                          !_loadingReflection)
                        GestureDetector(
                          onTap: () => _save(pop: false),
                          child: Text(
                            'Ask the mentor',
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.9),
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        isBookmarked
                            ? 'Kept forever'
                            : 'Tap the bookmark to keep this',
                        style: TextStyle(
                          color: isBookmarked
                              ? AppColors.primary.withValues(alpha: 0.8)
                              : AppColors.textTertiary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isEditing;
  final bool isBookmarked;
  final VoidCallback onBack;
  final VoidCallback onToggleBookmark;
  final VoidCallback? onDelete;
  final VoidCallback onSave;

  const _TopBar({
    required this.isEditing,
    required this.isBookmarked,
    required this.onBack,
    required this.onToggleBookmark,
    required this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          // Bookmark pill — lights up gold when kept.
          GestureDetector(
            onTap: onToggleBookmark,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: isBookmarked
                    ? LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.3),
                          AppColors.primary.withValues(alpha: 0.12),
                        ],
                      )
                    : null,
                color: isBookmarked
                    ? null
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isBookmarked
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: isBookmarked
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: isBookmarked
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isBookmarked ? 'Kept' : 'Keep',
                    style: TextStyle(
                      color: isBookmarked
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.war.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.war.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.war.withValues(alpha: 0.9),
                  size: 18,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8C87A), Color(0xFFD4A853)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Text(
                isEditing ? 'Save' : 'Write',
                style: const TextStyle(
                  color: Color(0xFF1A1208),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
