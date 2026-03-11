import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../constants/colors.dart';
import '../widgets/apex_card.dart';
import '../widgets/apex_button.dart';
import '../widgets/apex_screen_header.dart';
import '../services/supabase_service.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});
  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _uploading = false;
  bool _stitchMode = false;
  final List<Map<String, dynamic>> _selectedStitchPhotos = [];
  final _captionC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await SupabaseService.getProgressPhotos(
        SupabaseService.currentUser!.id,
      );
      if (mounted) {
        setState(() {
          _photos = p;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 75,
    );
    if (file == null) return;

    // Vibrate on start upload
    Haptics.vibrate(HapticsType.light);

    // Pre-prompt caption? No, just upload and maybe they can edit later, or keep the old one
    // Actually, capturing a simple dialog for caption might be better, or just direct upload for speed

    setState(() {
      _uploading = true;
    });

    try {
      final bytes =
          await FlutterImageCompress.compressWithFile(
            file.path,
            quality: 80,
            minWidth: 1400,
            minHeight: 1400,
            format: CompressFormat.jpeg,
          ) ??
          await file.readAsBytes();
      final base64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await SupabaseService.createProgressPhoto(
        SupabaseService.currentUser!.id,
        base64,
        _captionC.text.trim().isNotEmpty ? _captionC.text.trim() : null,
      );
      _captionC.clear();
      Haptics.vibrate(HapticsType.success);
      await _load();
    } catch (e) {
      Haptics.vibrate(HapticsType.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: ApexColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _uploading = false);
    }
  }

  void _showAddDialog() {
    Haptics.vibrate(HapticsType.light);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: ApexColors.surfaceStrong,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: ApexColors.border),
            boxShadow: [
              BoxShadow(
                color: ApexColors.shadow.withAlpha(50),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ApexColors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Add progress photo',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ApexColors.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture a new frame or pull one from your library.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: ApexColors.t2),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _captionC,
                  style: GoogleFonts.inter(fontSize: 14, color: ApexColors.t1),
                  decoration: InputDecoration(
                    hintText: 'Optional caption (e.g. Week 4 front pose)',
                    hintStyle: TextStyle(color: ApexColors.t3),
                    filled: true,
                    fillColor: ApexColors.cardAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ApexButton(
                        text: 'Camera',
                        icon: Icons.camera_alt_outlined,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _pickImage(ImageSource.camera);
                        },
                        tone: ApexButtonTone.outline,
                        color: ApexColors.t1,
                        full: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ApexButton(
                        text: 'Gallery',
                        icon: Icons.photo_library_outlined,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _pickImage(ImageSource.gallery);
                        },
                        tone: ApexButtonTone.outline,
                        color: ApexColors.t1,
                        full: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deletePhoto(String id) async {
    Haptics.vibrate(HapticsType.medium);
    await SupabaseService.deleteProgressPhoto(id);
    await _load();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final p in _photos) {
      final d = DateTime.tryParse(p['taken_at'] ?? '');
      final key = d != null ? '${_monthName(d.month)} ${d.year}' : 'Unknown';
      m.putIfAbsent(key, () => []).add(p);
    }
    return m;
  }

  String _monthName(int m) => [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][m - 1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by shell
      body: RefreshIndicator(
        onRefresh: _load,
        color: ApexColors.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            ApexScreenHeader(
              eyebrow: 'Progress',
              title: 'Photos',
              subtitle:
                  '${_photos.length} saved shots tracking your transformation.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_photos.length > 1)
                    GestureDetector(
                      onTap: () {
                        Haptics.vibrate(HapticsType.light);
                        setState(() {
                          _stitchMode = !_stitchMode;
                          _selectedStitchPhotos.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: _stitchMode ? ApexColors.accent : ApexColors.surface, borderRadius: BorderRadius.circular(8)),
                        child: Text('Stitch', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: _stitchMode ? ApexColors.bg : ApexColors.t2)),
                      ),
                    ),
                  if (_uploading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ApexColors.accent)),
                  ],
                ],
              ),
            ),
            if (_stitchMode)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: ApexCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select 2 photos to compare', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: ApexColors.accentSoft)),
                      Text('${_selectedStitchPhotos.length}/2', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: ApexColors.t1)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(color: ApexColors.accent),
                ),
              )
            else if (_photos.isEmpty)
              ApexCard(
                padding: const EdgeInsets.all(36),
                child: Column(
                  children: [
                    const Icon(
                      Icons.photo_camera_back_rounded,
                      size: 48,
                      color: ApexColors.t3,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No photos yet',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        color: ApexColors.t1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Take a photo today and start tracking\nyour transformation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ApexColors.t2,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._grouped.entries.map(
                (entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Divider(color: ApexColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 11,
                              color: ApexColors.t2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: ApexColors.border)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      children: entry.value
                          .map(
                            (p) => GestureDetector(
                              onTap: () {
                                Haptics.vibrate(HapticsType.light);
                                _showPhoto(p);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildImage(p['photo_data']),
                                    if (p['caption'] != null)
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(
                                            5,
                                            12,
                                            5,
                                            5,
                                          ),
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black87,
                                              ],
                                            ),
                                          ),
                                          child: Text(
                                            p['caption'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 8),
        child: FloatingActionButton(
          onPressed: _showAddDialog,
          backgroundColor: ApexColors.t1,
          foregroundColor: ApexColors.bg,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.add_a_photo_outlined),
        ),
      ),
    );
  }

  Widget _buildImage(String? data) {
    if (data == null) return Container(color: ApexColors.surface);
    if (data.startsWith('data:')) {
      final base64Str = data.split(',').last;
      return Image.memory(base64Decode(base64Str), fit: BoxFit.cover);
    }
    return Image.network(data, fit: BoxFit.cover);
  }

  void _showPhoto(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: ApexColors.t1),
            onPressed: () {
              Haptics.vibrate(HapticsType.light);
              Navigator.pop(ctx);
            },
          ),
          title: Text(
            _formatDate(photo['taken_at']),
            style: TextStyle(color: ApexColors.t2, fontSize: 10),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deletePhoto(photo['id']);
              },
              child: Text(
                '🗑 Delete',
                style: TextStyle(
                  color: ApexColors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImage(photo['photo_data']),
                  ),
                ),
              ),
            ),
            if (photo['caption'] != null)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  photo['caption'],
                  style: TextStyle(
                    color: ApexColors.t2,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return '${d.day} ${_monthName(d.month).substring(0, 3)} ${d.year}';
    } catch (_) {
      return '';
    }
  }


  @override
  void dispose() {
    _captionC.dispose();
    super.dispose();
  }
}
