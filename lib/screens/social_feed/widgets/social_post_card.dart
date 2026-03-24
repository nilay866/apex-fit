import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/colors.dart';
import '../../../widgets/apex_button.dart';
import '../../../widgets/apex_card.dart';
import '../../../widgets/apex_orb_logo.dart';

class SocialPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onClone;
  final VoidCallback onVersus;
  final bool cloning;

  const SocialPostCard({
    super.key,
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
                  label: name.toString().isNotEmpty ? name.toString()[0] : 'A',
                  imageData: avatar,
                  variant: ApexOrbVariant.light,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: ApexColors.t1,
                        ),
                      ),
                      Text(
                        _timeLabel(post['completed_at']?.toString()),
                        style: const TextStyle(
                          fontSize: 10,
                          color: ApexColors.t3,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onVersus,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ApexColors.surfaceStrong,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ApexColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.stacked_bar_chart_rounded,
                          size: 12,
                          color: ApexColors.t2,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Versus',
                          style: TextStyle(
                            color: ApexColors.t2,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              post['workout_name'] ?? 'Workout',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ApexColors.t1,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: ApexColors.t2,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post['duration_min'] ?? 0}m',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ApexColors.t2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.fitness_center_outlined,
                  size: 12,
                  color: ApexColors.t2,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(post['total_volume'] as num?)?.round() ?? 0}kg',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ApexColors.t2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
      );
    }
    return Image.network(
      data,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 200,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      cacheWidth: 1200,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: 200,
          color: ApexColors.surface,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: ApexColors.accent),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 200,
          color: ApexColors.surface,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            color: ApexColors.t3,
            size: 30,
          ),
        );
      },
    );
  }

  String _timeLabel(String? isoTimestamp) {
    final parsed = isoTimestamp == null
        ? null
        : DateTime.tryParse(isoTimestamp);
    if (parsed == null) return 'Recent';

    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
