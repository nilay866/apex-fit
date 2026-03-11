import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../constants/colors.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    final url = widget.exercise['video_url'] as String?;
    if (url != null && url.isNotEmpty) {
      _video = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          _video!.setLooping(true);
          _video!.play();
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApexColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: ApexColors.bg,
            expandedHeight: 280,
            pinned: true,
            iconTheme: const IconThemeData(color: ApexColors.bg),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.black,
                child: _video != null && _video!.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _video!.value.size.width,
                          height: _video!.value.size.height,
                          child: VideoPlayer(_video!),
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=2670&auto=format&fit=crop',
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(color: Colors.black26),
                          const Icon(Icons.play_circle_fill, size: 64, color: Colors.white70),
                        ],
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.exercise['name'] ?? '',
                    style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: ApexColors.t1),
                  ),
                  const SizedBox(height: 16),
                  
                  // Metadata Tiles
                  Row(
                    children: [
                      Expanded(child: _MetaTile(icon: Icons.accessibility_new, label: 'Muscle', value: widget.exercise['primary_muscle'] ?? '')),
                      const SizedBox(width: 12),
                      Expanded(child: _MetaTile(icon: Icons.fitness_center, label: 'Equipment', value: widget.exercise['equipment'] ?? '')),
                      const SizedBox(width: 12),
                      Expanded(child: _MetaTile(icon: Icons.home_work, label: 'Environment', value: widget.exercise['environment'] ?? '')),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Deep Taxonomy Taxonomy
                  _SectionHeader(title: 'PREPARATION STEPS'),
                  const SizedBox(height: 12),
                  Text(
                    widget.exercise['preparation_steps'] ?? 'Ensure proper form and clear the area.',
                    style: TextStyle(color: ApexColors.t2, fontSize: 15, height: 1.5),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  _SectionHeader(title: 'EXECUTION STEPS'),
                  const SizedBox(height: 12),
                  Text(
                    widget.exercise['execution_steps'] ?? 'Perform the movement under control.',
                    style: TextStyle(color: ApexColors.t2, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ApexColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ApexColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ApexColors.accent),
          const SizedBox(height: 12),
          Text(label.toUpperCase(), style: TextStyle(color: ApexColors.t3, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: ApexColors.t1, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: ApexColors.t1, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(width: 40, height: 3, decoration: BoxDecoration(color: ApexColors.accent, borderRadius: BorderRadius.circular(2))),
      ],
    );
  }
}
