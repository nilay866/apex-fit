import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../constants/colors.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_screen_header.dart';
import '../widgets/apex_orb_logo.dart';
import '../services/supabase_service.dart';
import '../services/social_service.dart';
import '../services/cache_service.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  bool _loading = true;
  bool _cloning = false;
  List<Map<String, dynamic>> _feed = [];

  @override
  void initState() {
    super.initState();
    // Synchronous hydration from holographic cache
    _feed = cache.get<List<Map<String, dynamic>>>(CacheService.keySocialFeed) ?? [];
    if (_feed.isEmpty) {
      _loading = true;
    } else {
      _loading = false;
    }
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    // We don't show the full-screen loader if we have cached content
    if (_feed.isEmpty) setState(() => _loading = true);
    
    try {
      final feed = await SocialService.getSocialFeed();
      if (mounted) {
        setState(() {
          _feed = feed;
          _loading = false;
        });
        // Sync to cache for next navigation
        cache.setList(CacheService.keySocialFeed, feed);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddCommunity() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _CommunityAddModal(onAdded: _loadFeed),
    );
  }

  Future<void> _cloneRoutine(Map<String, dynamic> post) async {
    Haptics.vibrate(HapticsType.medium);
    setState(() => _cloning = true);
    
    try {
      final wName = '${post['workout_name'] ?? 'Workout'} (Cloned)';
      final wType = post['type'] ?? 'hypertrophy';
      
      await SupabaseService.createWorkout(
        SupabaseService.currentUser!.id,
        wName,
        wType,
      );
      
      // In a real scenario, we'd fetch the exercises of this specific workout log
      // For now, we'll use a placeholder if the log doesn't have exercises joined.
      // Assuming social feed provides basic structure.
      
      if (mounted) {
        Haptics.vibrate(HapticsType.success);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$wName added to your routines!'),
            backgroundColor: ApexColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Haptics.vibrate(HapticsType.error);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clone routine.'), backgroundColor: ApexColors.red),
        );
      }
    }
    
    if (mounted) setState(() => _cloning = false);
  }

  void _showVersus(Map<String, dynamic> post) async {
    Haptics.vibrate(HapticsType.selection);
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
        onRefresh: _loadFeed,
        color: ApexColors.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ApexScreenHeader(
                  eyebrow: 'Community',
                  title: 'Social Feed',
                  subtitle: 'Real-time activity and routine syndication from your circles.',
                  trailing: IconButton(
                    onPressed: _showAddCommunity,
                    icon: const Icon(Icons.person_add_alt_1_rounded, color: ApexColors.accent),
                    style: IconButton.styleFrom(
                      backgroundColor: ApexColors.accent.withAlpha(20),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (_loading && _feed.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: ApexColors.accent)),
              )
            else if (_feed.isEmpty)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: ApexColors.t3.withAlpha(100)),
                      const SizedBox(height: 16),
                      Text('No activity yet.', style: TextStyle(color: ApexColors.t2, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Add friends to see their workouts and progress.', style: TextStyle(color: ApexColors.t3, fontSize: 13)),
                      const SizedBox(height: 24),
                      ApexButton(text: 'Find Friends', onPressed: _showAddCommunity, sm: true),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = _feed[index];
                      // Use RepaintBoundary to isolate card rendering for high-performance scrolling
                      return RepaintBoundary(
                        child: _SocialPostCard(
                          post: post, 
                          onClone: () => _cloneRoutine(post),
                          onVersus: () => _showVersus(post),
                          cloning: _cloning,
                        ),
                      );
                    },
                    childCount: _feed.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onClone;
  final VoidCallback onVersus;
  final bool cloning;

  const _SocialPostCard({
    required this.post,
    required this.onClone,
    required this.onVersus,
    required this.cloning,
  });

  @override
  Widget build(BuildContext context) {
    final profile = post['profiles'] ?? {};
    final name = profile['name'] ?? 'Athlete';
    final avatar = profile['avatar_data']?.toString();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ApexCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ApexOrbLogo(
                  size: 36,
                  label: name[0],
                  imageData: avatar,
                  variant: ApexOrbVariant.light,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: ApexColors.t1)),
                      Text('Today', style: TextStyle(fontSize: 10, color: ApexColors.t3)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onVersus,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ApexColors.surfaceStrong, 
                      borderRadius: BorderRadius.circular(8), 
                      border: Border.all(color: ApexColors.border)
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.stacked_bar_chart_rounded, size: 12, color: ApexColors.t2),
                        SizedBox(width: 6),
                        Text('Versus', style: TextStyle(color: ApexColors.t2, fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(post['workout_name'] ?? 'Workout', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: ApexColors.t1)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 12, color: ApexColors.t2),
                const SizedBox(width: 4),
                Text('${post['duration_min'] ?? 0}m', style: const TextStyle(fontSize: 12, color: ApexColors.t2, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                const Icon(Icons.fitness_center_outlined, size: 12, color: ApexColors.t2),
                const SizedBox(width: 4),
                Text('${(post['total_volume'] as num?)?.round() ?? 0}kg', style: const TextStyle(fontSize: 12, color: ApexColors.t2, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            if (post['photo_data'] != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildPostPhoto(post['photo_data'].toString()),
              ),
              const SizedBox(height: 16),
            ],
            ApexButton(
              text: 'Clone Routine',
              icon: Icons.content_copy_rounded,
              onPressed: onClone,
              loading: cloning,
              full: true,
              sm: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostPhoto(String data) {
    if (data.startsWith('data:')) {
      final base64Str = data.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
      );
    }
    return Image.network(
      data,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 200,
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

  void _search(String val) async {
    setState(() {
      _searching = val.isNotEmpty;
    });
    if (val.isEmpty) {
      setState(() => _results = []);
      return;
    }
    try {
      final res = await SocialService.searchProfiles(val);
      if (mounted) {
        setState(() {
          _results = res;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _connect(String id) async {
    Haptics.vibrate(HapticsType.medium);
    try {
      await SocialService.connectWithUser(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected!'), backgroundColor: ApexColors.accent),
        );
        widget.onAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: ${SupabaseService.describeError(e)}'), backgroundColor: ApexColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = SupabaseService.currentUser!;
    final athleteCode = me.id.substring(0, 8).toUpperCase();
    final qrData = jsonEncode({
      'id': me.id, 
      'code': athleteCode,
      'name': me.email?.split('@')[0] ?? 'User'
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
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ApexColors.border, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add to Community', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: ApexColors.t1)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: ApexColors.t3)),
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
                      Text('MY ATHLETE CODE', style: GoogleFonts.inter(fontSize: 10, color: ApexColors.t3, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 160.0,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ApexColors.t1),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ApexColors.t1),
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
                      Text('Show this to a peer in the gym to connect instantly.', textAlign: TextAlign.center, style: TextStyle(color: ApexColors.t2, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ApexButton(
                  text: _showScanner ? 'Close Scanner' : 'Scan Peer QR Code',
                  icon: _showScanner ? Icons.close : Icons.qr_code_scanner_rounded,
                  onPressed: () => setState(() => _showScanner = !_showScanner),
                  full: true,
                ),
                if (_showScanner) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 240,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20), border: Border.all(color: ApexColors.accent, width: 2)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: MobileScanner(
                        onDetect: (capture) {
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
                Text('SEARCH ATHLETES', style: GoogleFonts.inter(fontSize: 10, color: ApexColors.t3, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                const SizedBox(height: 12),
                TextField(
                  onChanged: _search,
                  style: const TextStyle(color: ApexColors.t1),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(color: ApexColors.t3),
                    prefixIcon: const Icon(Icons.search, color: ApexColors.t3),
                    filled: true,
                    fillColor: ApexColors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                if (_searching)
                  const Center(child: CircularProgressIndicator(color: ApexColors.accent))
                else
                  ..._results.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ApexOrbLogo(size: 40, label: (r['name'] ?? 'A')[0], imageData: r['avatar_data']?.toString()),
                    title: Text(r['name'] ?? 'Unknown', style: const TextStyle(color: ApexColors.t1, fontWeight: FontWeight.w700)),
                    subtitle: Text(r['goal'] ?? 'Athlete', style: const TextStyle(color: ApexColors.t3, fontSize: 11)),
                    trailing: ApexButton(text: 'Connect', onPressed: () => _connect(r['id'] as String), sm: true),
                  )),
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
        future: SocialService.getVersusStats(otherUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: ApexColors.accent)));
          }
          final stats = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ApexColors.border, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text('Versus Analytics', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: ApexColors.t1)),
              const SizedBox(height: 4),
              Text('Comparing your stats with $otherName', style: const TextStyle(color: ApexColors.t2, fontSize: 13)),
              const SizedBox(height: 32),
              _buildStatRow('Total Volume (kg)', stats['my_volume'], stats['their_volume'], otherName),
              const SizedBox(height: 16),
              _buildStatRow('Workouts Logged', stats['my_count'], stats['their_count'], otherName),
              const SizedBox(height: 32),
              ApexButton(text: 'Close', onPressed: () => Navigator.pop(context), outline: true, full: true),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic me, dynamic them, String theirName) {
    final iWin = (me as num) >= (them as num);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: ApexColors.t2, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statBox('You', me.toString(), iWin, ApexColors.accent)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('VS', style: TextStyle(color: ApexColors.t3, fontSize: 12, fontWeight: FontWeight.w900))),
            Expanded(child: _statBox(theirName, them.toString(), !iWin, ApexColors.orange)),
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
        crossAxisAlignment: win ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(color: ApexColors.t3, fontSize: 10), maxLines: 1),
          const SizedBox(height: 4),
          Text(stat, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: win ? color : ApexColors.t1)),
        ],
      ),
    );
  }
}
