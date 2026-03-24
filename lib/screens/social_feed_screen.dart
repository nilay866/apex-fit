import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/safe_haptics.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/colors.dart';
import '../repositories/social_repository.dart';
import '../repositories/workout_repository.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_screen_header.dart';
import '../widgets/apex_orb_logo.dart';
import '../services/supabase_service.dart';
import '../services/cache_service.dart';
import '../screens/challenges_screen.dart';
import 'social_feed/widgets/social_post_card.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  static const _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  String? _cloningPostId;
  bool _hasMore = true;
  List<Map<String, dynamic>> _feed = [];
  int _nextOffset = 0;

  @override
  void initState() {
    super.initState();
    // Synchronous hydration from holographic cache
    _feed =
        cache.get<List<Map<String, dynamic>>>(CacheService.keySocialFeed) ?? [];
    _nextOffset = _feed.length;
    if (_feed.isEmpty) {
      _loading = true;
    } else {
      _loading = false;
    }
    _scrollController.addListener(_handleScroll);
    _loadFeed(refresh: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadFeed();
    }
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (_loadingMore) return;
    if (!refresh && !_hasMore) return;

    final showFullLoader = _feed.isEmpty;
    if (mounted) {
      setState(() {
        if (showFullLoader) {
          _loading = true;
        } else {
          _loadingMore = true;
        }
      });
    }

    try {
      final page = await socialRepository.fetchFeedPage(
        offset: refresh ? 0 : _nextOffset,
        pageSize: _pageSize,
      );
      if (mounted) {
        final mergedItems = refresh ? page.items : [..._feed, ...page.items];
        final dedupedItems = <String, Map<String, dynamic>>{};
        for (final item in mergedItems) {
          dedupedItems[item['id']?.toString() ?? UniqueKey().toString()] = item;
        }
        setState(() {
          _feed = dedupedItems.values.toList();
          _nextOffset = page.nextOffset;
          _hasMore = page.hasMore;
          _loading = false;
          _loadingMore = false;
        });
        cache.setList(CacheService.keySocialFeed, _feed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _showAddCommunity() {
    if (SupabaseService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in again to manage your community.'),
          backgroundColor: ApexColors.red,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _CommunityAddModal(onAdded: () => _loadFeed(refresh: true)),
    );
  }

  Future<void> _cloneRoutine(Map<String, dynamic> post) async {
    final postId = post['id']?.toString();
    if (postId == null || postId.isEmpty) {
      return;
    }

    SafeHaptics.vibrate(HapticsType.medium);
    setState(() => _cloningPostId = postId);

    try {
      final result = await workoutRepository.cloneWorkoutFromSocialPost(post);

      if (mounted) {
        SafeHaptics.vibrate(HapticsType.success);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.clonedExerciseCount > 0
                  ? '${result.workout['name']} added with ${result.clonedExerciseCount} exercises.'
                  : '${result.workout['name']} added to your routines.',
            ),
            backgroundColor: ApexColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SafeHaptics.vibrate(HapticsType.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SupabaseService.describeError(e)),
            backgroundColor: ApexColors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _cloningPostId = null);
  }

  void _showVersus(Map<String, dynamic> post) async {
    SafeHaptics.vibrate(HapticsType.selection);
    final userId = post['user_id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _VersusModal(
        otherUserId: userId,
        otherName: (post['profiles']?['name'] ?? 'Athlete').toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _loadFeed(refresh: true),
        color: ApexColors.accent,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ApexScreenHeader(
                  eyebrow: 'Community',
                  title: 'Social Feed',
                  subtitle:
                      'Real-time activity and routine syndication from your circles.',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // NEW: Challenges shortcut
                      IconButton(
                        key: const ValueKey('social_challenges_button'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ChallengesScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.emoji_events_rounded,
                          color: ApexColors.yellow,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: ApexColors.yellow.withAlpha(20),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const ValueKey('social_add_community_button'),
                        onPressed: _showAddCommunity,
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: ApexColors.accent,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: ApexColors.accent.withAlpha(20),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_loading && _feed.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: ApexColors.accent),
                ),
              )
            else if (_feed.isEmpty)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 48,
                        color: ApexColors.t3.withAlpha(100),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No activity yet.',
                        style: TextStyle(
                          color: ApexColors.t2,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add friends to see their workouts and progress.',
                        style: TextStyle(color: ApexColors.t3, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ApexButton(
                        key: const ValueKey('social_find_friends_button'),
                        text: 'Find Friends',
                        onPressed: _showAddCommunity,
                        sm: true,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final post = _feed[index];
                    // Use RepaintBoundary to isolate card rendering for high-performance scrolling
                    return RepaintBoundary(
                      child: SocialPostCard(
                        post: post,
                        onClone: () => _cloneRoutine(post),
                        onVersus: () => _showVersus(post),
                        cloning: _cloningPostId == post['id']?.toString(),
                      ),
                    );
                  }, childCount: _feed.length),
                ),
              ),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 120),
                  child: Center(
                    child: CircularProgressIndicator(color: ApexColors.accent),
                  ),
                ),
              )
            else if (_feed.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Center(
                    child: Text(
                      _hasMore ? '' : 'You are caught up.',
                      style: const TextStyle(
                        color: ApexColors.t3,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommunityAddModal extends StatefulWidget {
  final VoidCallback onAdded;
  const _CommunityAddModal({required this.onAdded});

  @override
  State<_CommunityAddModal> createState() => _CommunityAddModalState();
}

class _CommunityAddModalState extends State<_CommunityAddModal> {
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _showScanner = false;
  bool _connecting = false;
  String? _activeQuery;
  String? _connectingUserId;
  int _queryVersion = 0;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _activeQuery = '';
        _searching = false;
        _results = [];
      });
      return;
    }

    final nextVersion = ++_queryVersion;
    setState(() {
      _activeQuery = query;
      _searching = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 320), () async {
      try {
        final res = await socialRepository.searchProfiles(query);
        if (!mounted || nextVersion != _queryVersion) return;
        setState(() {
          _results = res;
          _searching = false;
        });
      } catch (_) {
        if (!mounted || nextVersion != _queryVersion) return;
        setState(() => _searching = false);
      }
    });
  }

  Future<void> _connect(String id) async {
    if (_connecting) return;
    SafeHaptics.vibrate(HapticsType.medium);
    setState(() {
      _connecting = true;
      _connectingUserId = id;
    });
    try {
      await socialRepository.connectWithUser(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected!'),
            backgroundColor: ApexColors.accent,
          ),
        );
        widget.onAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection failed: ${SupabaseService.describeError(e)}',
            ),
            backgroundColor: ApexColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
          _connectingUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = SupabaseService.currentUser;
    if (me == null) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: const BoxDecoration(
          color: ApexColors.surfaceStrong,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Session expired',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: ApexColors.t1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in again to search athletes and connect with friends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ApexColors.t2, fontSize: 13),
                ),
                const SizedBox(height: 18),
                ApexButton(
                  text: 'Close',
                  onPressed: () => Navigator.pop(context),
                  tone: ApexButtonTone.outline,
                  full: true,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final athleteCode = me.id.substring(0, 8).toUpperCase();
    final qrData = jsonEncode({
      'id': me.id,
      'code': athleteCode,
      'name': me.email?.split('@')[0] ?? 'User',
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: ApexColors.surfaceStrong,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ApexColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add to Community',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: ApexColors.t1,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: ApexColors.t3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                // QR Display
                ApexCard(
                  child: Column(
                    children: [
                      Text(
                        'MY ATHLETE CODE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: ApexColors.t3,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 160.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: ApexColors.t1,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: ApexColors.t1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        athleteCode,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: ApexColors.t1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Show this to a peer in the gym to connect instantly.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ApexColors.t2, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ApexButton(
                  key: const ValueKey('social_scanner_toggle_button'),
                  text: _showScanner ? 'Close Scanner' : 'Scan Peer QR Code',
                  icon: _showScanner
                      ? Icons.close
                      : Icons.qr_code_scanner_rounded,
                  onPressed: () => setState(() => _showScanner = !_showScanner),
                  full: true,
                ),
                if (_showScanner) ...[
                  const SizedBox(height: 16),
                  if (kIsWeb)
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        color: ApexColors.cardAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          'QR scanning is not available in the web browser.\nUse the mobile app to scan QR codes.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: ApexColors.t2),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ApexColors.accent, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: MobileScanner(
                          onDetect: (capture) {
                            if (_connecting) return;
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              if (barcode.rawValue != null) {
                                try {
                                  final data = jsonDecode(barcode.rawValue!);
                                  if (data['id'] != null) {
                                    _connect(data['id'] as String);
                                  }
                                } catch (_) {}
                              }
                            }
                          },
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                Text(
                  'SEARCH ATHLETES',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: ApexColors.t3,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('social_search_field'),
                  onChanged: _search,
                  style: const TextStyle(color: ApexColors.t1),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(color: ApexColors.t3),
                    prefixIcon: const Icon(Icons.search, color: ApexColors.t3),
                    filled: true,
                    fillColor: ApexColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_searching)
                  const Center(
                    child: CircularProgressIndicator(color: ApexColors.accent),
                  )
                else if ((_activeQuery ?? '').isNotEmpty && _results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No athletes matched that search yet.',
                      style: TextStyle(color: ApexColors.t3, fontSize: 12),
                    ),
                  )
                else
                  ..._results.map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ApexOrbLogo(
                        size: 40,
                        label: (r['name'] ?? 'A')[0],
                        imageData: r['avatar_data']?.toString(),
                      ),
                      title: Text(
                        r['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: ApexColors.t1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        r['goal'] ?? 'Athlete',
                        style: const TextStyle(
                          color: ApexColors.t3,
                          fontSize: 11,
                        ),
                      ),
                      trailing: ApexButton(
                        key: ValueKey('connect_user_${r['id']}'),
                        text: 'Connect',
                        onPressed: () => _connect(r['id'] as String),
                        loading: _connectingUserId == r['id']?.toString(),
                        disabled: _connecting && _connectingUserId != r['id'],
                        sm: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VersusModal extends StatelessWidget {
  final String otherUserId;
  final String otherName;

  const _VersusModal({required this.otherUserId, required this.otherName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: ApexColors.surfaceStrong,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: socialRepository.getVersusStats(otherUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Versus stats unavailable',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: ApexColors.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ApexColors.t2, fontSize: 12),
                ),
                const SizedBox(height: 20),
                ApexButton(
                  text: 'Close',
                  onPressed: () => Navigator.pop(context),
                  tone: ApexButtonTone.outline,
                  full: true,
                ),
                const SizedBox(height: 24),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 300,
              child: Center(
                child: CircularProgressIndicator(color: ApexColors.accent),
              ),
            );
          }
          final stats = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ApexColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Versus Analytics',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: ApexColors.t1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Comparing your stats with $otherName',
                style: const TextStyle(color: ApexColors.t2, fontSize: 13),
              ),
              const SizedBox(height: 32),
              _buildStatRow(
                'Total Volume (kg)',
                stats['my_volume'],
                stats['their_volume'],
                otherName,
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                'Workouts Logged',
                stats['my_count'],
                stats['their_count'],
                otherName,
              ),
              const SizedBox(height: 32),
              ApexButton(
                text: 'Close',
                onPressed: () => Navigator.pop(context),
                outline: true,
                full: true,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    dynamic me,
    dynamic them,
    String theirName,
  ) {
    final iWin = (me as num) >= (them as num);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ApexColors.t2,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statBox('You', me.toString(), iWin, ApexColors.accent),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'VS',
                style: TextStyle(
                  color: ApexColors.t3,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: _statBox(
                theirName,
                them.toString(),
                !iWin,
                ApexColors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statBox(String label, String stat, bool win, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: win ? color.withAlpha(40) : ApexColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: win ? color : ApexColors.border),
      ),
      child: Column(
        crossAxisAlignment: win
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(color: ApexColors.t3, fontSize: 10),
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            stat,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: win ? color : ApexColors.t1,
            ),
          ),
        ],
      ),
    );
  }
}
